//
//  FDNReverb.hpp
//  fdnreverb
//
//  Created by Jay Coggin on 2/4/15.
//  Copyright © 2015 Jay Coggin. All rights reserved.
//

#ifndef _fdnreverb_FDNReverb_
#define _fdnreverb_FDNReverb_

#include "CircularDelay.h"
#include "MultiSectionBiQuad.h"

#include <stdio.h>
#include <vector>

namespace fftconvolver {
    class FFTConvolver;
};

class FDNReverb {
public:
    FDNReverb(int maxFramesPerSlice,
              int blockSize,
              int fs,
              const std::vector<int>& delays,
              const std::vector<float>& bCoeffs,
              const std::vector<float>& cCoeffs,
              const std::vector<float>& aCoeffs,
              float d);
    
    void SetEarlyReflectionsIR(float* ir, int length);
    void SetFilterCoeffs(const std::vector<float>& coeffs);
    void SetToneCorrectionBQCoeffs(const std::vector<float>& coeffs);
    void SetToneCorrectionFIRCoeffs(float* ir, int length);
    
    void Process(float* input, float* output, int numFrames);
    
private:
    
    const std::vector<float> mBCoeffs;
    const std::vector<float> mCCoeffs;
    const std::vector<float> mACoeffs;
    const float mD;
    const int mMaxFramesPerSlice;
    const int mBlockSize;
    const int mOrder;
    
    std::vector<float> mLPCutoffs;
    std::unique_ptr<fftconvolver::FFTConvolver> mEarlyFIR;
    std::unique_ptr<fftconvolver::FFTConvolver> mToneCorrectionFIR;
    std::vector<std::unique_ptr<ElementDelay>> mDelays;
    std::vector<std::unique_ptr<MultiSectionBiQuad>> mBQs;
    std::unique_ptr<MultiSectionBiQuad> mTCBQ;
    
    std::vector<float> mEarlyIROutBuf;
    
    // size of moDrder vector that holds the delay line read value during each iteration
    std::vector<float> mDelayOutsBuf;
    
    // decaying biquad outputs
    std::vector<float> mBQOutsBuf;

    std::vector<float*> mBQInPtrs;
    std::vector<float*> mBQOutPtrs;
    std::vector<float> mMatrixMultOutBuf;
    std::vector<float> mDelayInBuf;
    
};

#endif /* defined(_fdnreverb_FDNReverb_) */
