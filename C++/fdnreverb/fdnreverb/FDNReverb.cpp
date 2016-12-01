//
//  FDNReverb.cpp
//  fdnreverb
//
//  Created by Jay Coggin on 2/4/15.
//  Copyright © 2015 Jay Coggin. All rights reserved.
//

#include "FDNReverb.hpp"
#include "CAXException.h"

#include <Accelerate/Accelerate.h>

#include "FFTConvolver.h"

using namespace std;
using namespace fftconvolver;

inline int
pow2roundup (int x)
{
    if (x < 0)
        return 0;
    --x;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    return x+1;
}

FDNReverb::FDNReverb(int maxFramesPerSlice,
                     int blockSize,
                     int fs,
                     const std::vector<int>& delays,
                     const std::vector<float>& bCoeffs,
                     const std::vector<float>& cCoeffs,
                     const std::vector<float>& aCoeffs,
                     float d) :
mBCoeffs(bCoeffs),
mCCoeffs(cCoeffs),
mACoeffs(aCoeffs),
mD(d),
mMaxFramesPerSlice(maxFramesPerSlice),
mBlockSize(blockSize),
mEarlyIROutBuf(maxFramesPerSlice, 0.0),
mOrder((int)delays.size()),
mDelayOutsBuf(mOrder, 0.0f),
mBQOutsBuf(mOrder, 0.0f),
mMatrixMultOutBuf(mOrder),
mDelayInBuf(mOrder, 0.0f)
{
    XThrowIf(mBCoeffs.size() != mOrder, -1, "B coeffs are incorrect length");
    XThrowIf(mCCoeffs.size() != mOrder, -1, "C coeffs are incorrect length");
    XThrowIf(mACoeffs.size() != mOrder*mOrder, -1, "A coeffs are incorrect length");
    
    for (int i = 0; i < mOrder; i++) {
        mDelays.emplace_back(make_unique<ElementDelay>(delays[i]));
        mDelays[i]->SetDelaySamples(delays[i]);
        
        // BQ pointer setup
        mBQInPtrs.push_back(&mDelayOutsBuf[i]);
        mBQOutPtrs.push_back(&mBQOutsBuf[i]);
    }
}

void FDNReverb::SetEarlyReflectionsIR(float* ir, int length)
{
    if (ir && length) {
        int pow2Len = pow2roundup(length);
        vector<float> mFixedCoeffs(pow2Len, 0.0f);
        memcpy(mFixedCoeffs.data(), ir, sizeof(float)*length);
        mEarlyFIR = make_unique<FFTConvolver>();
        mEarlyFIR->init(mBlockSize, mFixedCoeffs.data(), pow2Len);
    }
}

void FDNReverb::SetFilterCoeffs(const std::vector<float>& coeffs)
{
    if (coeffs.size() % mOrder || coeffs.size() % 5) {
        printf("Coeff vector is an invalid size: %lu\n", coeffs.size());
        return;
    }
    const int numSections = (int)coeffs.size()/(mOrder*5);
    vector<double> dCoeffs(numSections*5);
    
    mBQs.clear();
    for (int c = 0; c < mOrder; c++) {
        mBQs.emplace_back(make_unique<MultiSectionBiQuad>(numSections, mMaxFramesPerSlice));
        vDSP_vspdp(&coeffs.at(5*numSections*c), 1, dCoeffs.data(), 1, dCoeffs.size());
        mBQs.back()->Initialize(dCoeffs.data());
    }
}

void FDNReverb::SetToneCorrectionBQCoeffs(const std::vector<float>& coeffs)
{
    if (coeffs.size() % 5) {
        printf("Coeff vector is an invalid size: %lu\n", coeffs.size());
        return;
    }
    const int numSections = (int)coeffs.size()/5;
    mTCBQ = make_unique<MultiSectionBiQuad>(numSections, mMaxFramesPerSlice);
    vector<double> dCoeffs(numSections*5);
    vDSP_vspdp(coeffs.data(), 1, dCoeffs.data(), 1, dCoeffs.size());
    mTCBQ->Initialize(dCoeffs.data());
}


void FDNReverb::SetToneCorrectionFIRCoeffs(float* ir, int length)
{
    if (ir && length) {
        int pow2Len = pow2roundup(length);
        vector<float> mFixedCoeffs(pow2Len, 0.0f);
        memcpy(mFixedCoeffs.data(), ir, sizeof(float)*length);
        mToneCorrectionFIR = make_unique<FFTConvolver>();
        mToneCorrectionFIR->init(mBlockSize, mFixedCoeffs.data(), pow2Len);
    }
}

void FDNReverb::Process(float* input, float* output, int numFrames)
{
    assert(numFrames <= mMaxFramesPerSlice);
    
    // process chunk through early IR if applicable
    if (mEarlyFIR.get()) {
        mEarlyFIR->process(input, mEarlyIROutBuf.data(), numFrames);
    }
    
    float* fdnIn = mEarlyFIR.get() ? mEarlyIROutBuf.data() : input;
    float* matrixFeed = mBQs.size() ? mBQOutsBuf.data() : mDelayOutsBuf.data();
    
    for (int i = 0; i < numFrames; i++) {
        
        // read one sample from each delay line
        for (int bq = 0; bq < mOrder; bq++) {
            *mBQInPtrs[bq] = mDelays[bq]->Read();
        }
        
        // send the delay outputs through the decaying biquads
        if (mBQs.size()) {
            for (int m = 0; m < mOrder; m++) {
                mBQs[m]->Process(&mDelayOutsBuf[m], &mBQOutsBuf[m], 1);
            }
        }
        
        // multiply accumulate with the C coefficients, write to output buffer
        vDSP_dotpr(matrixFeed, 1, mCCoeffs.data(), 1, output + i, mOrder);
        
        // optionally apply the tone tone correction bi-quad (used with Jot's corretion method)
        if (mTCBQ.get()) {
            mTCBQ->Process(output + i, output + i, 1);
        }
        
        // multiply the matrix by the delay line / EQ outputs, scale input by B's, sum with output from matrix multiply, write the delay lines
        vDSP_mmul(mACoeffs.data(), 1, matrixFeed, 1, mMatrixMultOutBuf.data(), 1, mOrder, 1, mOrder);
        vDSP_vsma(mBCoeffs.data(), 1, fdnIn + i, mMatrixMultOutBuf.data(), 1, mDelayInBuf.data(), 1, mOrder);
        for (int del = 0; del < mOrder; del++) {
            mDelays[del]->Write(mDelayInBuf[del]);
        }
    }
    
    // optionally apply tone correction FIR (used with empirical correction method developed in this work)
    if (mToneCorrectionFIR.get()) {
        mToneCorrectionFIR->process(output, output, numFrames);
    }
    
    // mix in direct signal. Multiply input vector by scalar D then sum with output
    vDSP_vsma(fdnIn, 1, &mD, output, 1, output, 1, numFrames);
}

