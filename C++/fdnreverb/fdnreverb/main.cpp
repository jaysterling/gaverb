//
//  main.cpp
//  fdnreverb
//
//  Created by Jay Coggin on 2/4/15.
//  Copyright © 2015 Jay Coggin. All rights reserved.
//

#include "CAStreamBasicDescription.h"
#include "CAExtAudioFile.h"
#include "CABufferList.h"
#include "CAHostTimeBase.h"
#include "FDNReverb.hpp"
#include "EnvelopeDetector.hpp"

#include <iostream>
#include <vector>
#include <string>
#include <sstream>

#include <MacTypes.h>
#include <AudioToolbox/AudioToolbox.h>
#include <Accelerate/Accelerate.h>

#include "FFTConvolver.h"

using namespace std;

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

bool isFloat( string myString ) {
    std::istringstream iss(myString);
    float f;
    iss >> noskipws >> f; // noskipws considers leading whitespace invalid
    // Check the entire string was consumed and if either failbit or badbit is set
    return iss.eof() && !iss.fail();
}

OSStatus GetFloat(const char* arg, float& outValue)
{
    if (isFloat(arg)) {
        outValue = std::atof(arg);
        return noErr;
    }
    return -1;
}

int main(int argc, const char * argv[]) {

    int dim = 0, fs = 0, maxSamps = 0;
    UInt32 blockSize = 4096;
    float d = 0.0, preScale = 1.0;
    string inPath, outPath, earlyReflectionsPath;
    bool verbose = false;
    
    float envAttTime_ms = 50;
    float envDecTime_ms = 500;
    float dbThreshToExit = -90;
    float timeBelowThreshToExit_ms = 500;
    
    // A is read in row-wise. First row, 2nd row, etc
    vector<float> A, B, C, BQ,TBQ,TFIR;
    vector<int> D;
    
    for (int i = 1; i < argc; ++i)
    {
        if (strcmp (argv[i], "-dim") == 0) {
            sscanf(argv[++i], "%d", &dim);
        }
        else if (strcmp (argv[i], "-b") == 0 && dim) {
            float val;
            for (int ind = 0; ind < dim; ind++) {
                if (noErr != GetFloat(argv[++i], val)) {
                    printf("Error parsing B coeffs at item %d\n", ind + 1);
                    exit(-1);
                }
                B.push_back(val);
            }
        }
        else if (strcmp (argv[i], "-c") == 0 && dim) {
            float val;
            for (int ind = 0; ind < dim; ind++) {
                if (noErr != GetFloat(argv[++i], val)) {
                    printf("Error parsing C coeffs at item %d\n", ind + 1);
                    exit(-1);
                }
                C.push_back(val);
            }
        }
        else if (strcmp (argv[i], "-A") == 0 && dim) {
            float val;
            for (int ind = 0; ind < dim*dim; ind++) {
                if (noErr != GetFloat(argv[++i], val)) {
                    printf("Error parsing A coeffs at item %d\n", ind + 1);
                    exit(-1);
                }
                A.push_back(val);
            }
        }
        // decaying biquads, applied right after each delay line to achieve the proper T60(f) curve
        else if (strcmp (argv[i], "-BQ") == 0 && dim) {
            float val;
            for (;;) {
                if (noErr != GetFloat(argv[++i], val)) {
                    i--;    // back up the read index
                    break;
                }
                BQ.push_back(val);
            }
        }
        // tone correction biquad coefficients (only used when using Jot's tone correction method)
        else if (strcmp (argv[i], "-TBQ") == 0 && dim) {
            float val;
            for (;;) {
                if (noErr != GetFloat(argv[++i], val)) {
                    i--;    // back up the read index
                    break;
                }
                TBQ.push_back(val);
            }
        }
        // tone correction FIR, used when using the empirical correction method detailed in the thesis
        else if (strcmp (argv[i], "-TFIR") == 0 && dim) {
            float val;
            for (;;) {
                if (noErr != GetFloat(argv[++i], val)) {
                    i--;    // back up the read index
                    break;
                }
                TFIR.push_back(val);
            }
        }
        else if (strcmp (argv[i], "-d") == 0) {\
            if (noErr != GetFloat(argv[++i], d)) {
                printf("Error parsing d coeff\n");
                exit(-1);
            }
        }
        else if (strcmp (argv[i], "-del") == 0 && dim) {
            float val;
            for (int ind = 0; ind < dim; ind++) {
                if (noErr != GetFloat(argv[++i], val)) {
                    printf("Error parsing delays at item %d\n", ind + 1);
                    exit(-1);
                }
                D.push_back(val);
            }
        }
        else if (strcmp (argv[i], "-fs") == 0) {
            float val;
            if (noErr != GetFloat(argv[++i], val)) {
                printf("Error parsing sampling freq\n");
                exit(-1);
            }
            fs = static_cast<int>(val);
        }
        else if (strcmp (argv[i], "-ms") == 0) {
            float val;
            if (noErr != GetFloat(argv[++i], val)) {
                printf("Error parsing max number of samples to run\n");
                exit(-1);
            }
            maxSamps = static_cast<int>(val);
        }
        else if (strcmp (argv[i], "-v") == 0) {
            verbose = true;
        }
        else if (strcmp (argv[i], "-in") == 0) {
            inPath = argv[++i];
        }
        else if (strcmp (argv[i], "-out") == 0) {
            outPath = argv[++i];
        }
        else if (strcmp (argv[i], "-early") == 0) {
            earlyReflectionsPath = argv[++i];
        }
        else if (strcmp (argv[i], "-bs") == 0) {
            sscanf(argv[++i], "%d", &blockSize);
        }
        else if (strcmp (argv[i], "-ps") == 0) {
            sscanf(argv[++i], "%f", &preScale);
        }
        else {
            printf("bad option: '%s'\n", argv[i]);
            exit(1);
        }
    }
    
    bool convolveEarlyOnly = A.empty() && B.empty() && C.empty() && BQ.empty() && TBQ.empty() && TFIR.empty() && D.empty() && !earlyReflectionsPath.empty() && fs;
    
    if (fs == 0) {
        printf("Sampling frequency must be set\n");
        exit(1);
    }
    if (outPath.empty()) {
        printf("Output path must be set\n");
        exit(1);
    }
    if (maxSamps == 0 && inPath.empty()) {
        printf("Max number of samples must be set\n");
        exit(1);
    }
    if (!convolveEarlyOnly) {
        if (dim == 0) {
            printf("Order must be set\n");
            exit(1);
        }
        if (A.size() != dim*dim) {
            printf("Feedback matrix has incorrect size\n");
            exit(1);
        }
        if (B.size() != dim) {
            printf("B vector has incorrect size\n");
            exit(1);
        }
        if (C.size() != dim) {
            printf("C vector has incorrect size\n");
            exit(1);
        }
        if (D.size() != dim) {
            printf("Delays vector has incorrect size\n");
            exit(1);
        }
        if (BQ.size() % dim || BQ.size() % 5) {
            printf("Read in %lu BQ coeffs, must be an integer multiple of both 5 and dim\n", BQ.size());
        }
        if (TBQ.size() % 5) {
            printf("Tone correction BQ coeffs must be multiple of 5\n");
        }
    }
    
    if (verbose) {
        if (convolveEarlyOnly) {
            printf("Setup for convolution reverb (using file in early IR path)\n");
        }
        printf("Fs: %d\nBlockSize : %d\nInput Pre-scaling: %0.3f\n", fs, blockSize, preScale);
        if (!convolveEarlyOnly) {
            printf("FDN PARAMS:\n\nOrder : %d\n", dim);
            
            printf("b : ");
            for (auto b : B)
                printf("%0.3f   ", b);
            printf("\n");
            
            printf("c : ");
            for (auto c : C)
                printf("%0.3f   ", c);
            printf("\n");
            
            printf("A : \n");
            for (int row = 0; row < dim; row++) {
                printf("\t");
                for (int col = 0; col < dim; col++)
                    printf("%0.3f   ", A[row*dim + col]);
                printf("\n");
            }
            
            printf("delays : ");
            for (auto d : D)
                printf("%d   ", d);
            printf("\n");
            
            if (BQ.size()) {
                printf("BQ coeffs : \n\t");
                for (int n = 0; n < dim; n++) {
                    for (int i = 0; i < BQ.size()/dim; i++) {
                        printf("%0.4f  ", BQ[n*dim + i]);
                    }
                }
                printf("\n\t");
            }
            if (TBQ.size()) {
                printf("Tone Corrector BQ coeffs : \n\t");
                for (int i = 0; i < TBQ.size(); i++) {
                    printf("%0.4f  ", TBQ[i]);
                }
                printf("\n\t");
            }
            if (TFIR.size()) {
                printf("Tone Corrector FIR: \n\t");
                for (int i = 0; i < std::min<size_t>(TFIR.size(),16); i++) {
                    printf("%0.4f  ", TFIR[i]);
                }
                printf("\n\t");
            }
            
            printf("d : %0.3f\n", d);
        }

        printf("Input file: %s\n", inPath.c_str());
        printf("Early reflections file: %s\n", earlyReflectionsPath.c_str());
        printf("Output file: %s\n", outPath.c_str());
    }
    
    float linGainToExit = powf(10.0, dbThreshToExit/20.0);
    int samplesBelowThreshToExit = fs*(timeBelowThreshToExit_ms/1000.0f);
    
    try {
        CAStreamBasicDescription fdnFmt(fs, 1, CAStreamBasicDescription::CommonPCMFormat::kPCMFormatFloat32, false);
        
        CAExtAudioFile earlyIRFile;
        CABufferList* earlyIRBL(CABufferList::New(fdnFmt));
        UInt32 earlyIRDataLen = 0;
        if (!earlyReflectionsPath.empty()) {
            earlyIRFile.Open(earlyReflectionsPath.c_str());
            earlyIRFile.SetClientFormat(fdnFmt);
            SInt64 fileLen = earlyIRFile.GetNumberFrames();
            int fileSR = (int)earlyIRFile.GetFileDataFormat().mSampleRate;
            if (fileSR != fs) {
                printf("Early reflections IR file is at a different SR (%d) than the set SR (%d) - resampling will be done but this is not recommended\n", fileSR, fs);
            }
            earlyIRBL->AllocateBuffers((UInt32)fileLen*fdnFmt.mBytesPerFrame);
            earlyIRDataLen = static_cast<UInt32>(fileLen);
            earlyIRFile.Read(earlyIRDataLen, &earlyIRBL->GetModifiableBufferList());
            if (earlyIRDataLen != fileLen) {
                printf("Did not read entire early IR file in\n");
            }
        }
        
        unique_ptr<FDNReverb> fdn;
        unique_ptr<fftconvolver::FFTConvolver> fir;
        if (!convolveEarlyOnly) {
            fdn = make_unique<FDNReverb>(blockSize, blockSize, fs, D, B, C, A, d);
            if (BQ.size()) {
                fdn->SetFilterCoeffs(BQ);
            }
            if (earlyIRFile.IsValid()) {
                fdn->SetEarlyReflectionsIR(static_cast<float*>(earlyIRBL->GetBufferList().mBuffers[0].mData), earlyIRDataLen);
            }
            if (TBQ.size()) {
                fdn->SetToneCorrectionBQCoeffs(TBQ);
            }
            if (TFIR.size()) {
                fdn->SetToneCorrectionFIRCoeffs(TFIR.data(), (int)TFIR.size());
            }
        }
        else {
            int pow2Len = pow2roundup(earlyIRDataLen);
            if (verbose) {
                printf("Actual IR length: %d\nPadded length: %d\n", earlyIRDataLen, pow2Len);
            }
            vector<float> mFixedCoeffs(pow2Len, 0.0f);
            memcpy(mFixedCoeffs.data(), earlyIRBL->GetModifiableBufferList().mBuffers[0].mData, sizeof(float)*earlyIRDataLen);
            fir = make_unique<fftconvolver::FFTConvolver>();
            fir->init(blockSize, mFixedCoeffs.data(), pow2Len);
        }
        
        EnvelopeDetector envelope(fs);
        envelope.SetAttackTime(envAttTime_ms);
        envelope.SetReleaseTime(envDecTime_ms);
        
        CAExtAudioFile inputFile;
        if (!inPath.empty()) {
            inputFile.Open(inPath.c_str());
            inputFile.SetClientFormat(fdnFmt);
        }
        
        CAExtAudioFile outputFile;
        outputFile.Create(outPath.c_str(), kAudioFileWAVEType, fdnFmt, NULL, kAudioFileFlags_EraseFile);
        
        CABufferList* inputBL(CABufferList::New(fdnFmt));
        inputBL->AllocateBuffers(blockSize*fdnFmt.mBytesPerFrame);
        if (!inputFile.IsValid()) {
            inputBL->SetToZeroes(blockSize*fdnFmt.mBytesPerFrame);
        }
        
        CABufferList* outputBL(CABufferList::New(fdnFmt));
        outputBL->AllocateBuffers(blockSize*fdnFmt.mBytesPerFrame);
        int samplesProcessed = 0;
        
        float* inData = static_cast<float*>(inputBL->GetModifiableBufferList().mBuffers[0].mData);
        float* outData = static_cast<float*>(outputBL->GetModifiableBufferList().mBuffers[0].mData);
        if (!inputFile.IsValid()) {
            inData[0] = 1.0;    // impulse
        }
        vector<float> envOut(blockSize);
        int sampsBelowThresh = 0;
        float maxValue = 0.0f;
        
        UInt64 totalProcessTime = 0;
        while (inputFile.IsValid() ? 1 : samplesProcessed < maxSamps) {
            
            UInt32 thisBlockSize = blockSize;
            if (samplesProcessed == blockSize && !inputFile.IsValid()) {
                inData[0] = 0.0;    // after first pass, zero it out for IR
            }
            if (inputFile.IsValid()) {
                inputFile.Read(thisBlockSize, &inputBL->GetModifiableBufferList());
                vDSP_vsmul(inData, 1, &preScale, inData, 1, thisBlockSize);
            }
            
            UInt64 startTime = CAHostTimeBase::GetCurrentTime();
            if (!convolveEarlyOnly) {
                fdn->Process(inData, outData, thisBlockSize);
            }
            else {
                fir->process(inData, outData, thisBlockSize);
            }
            totalProcessTime += CAHostTimeBase::GetCurrentTime() - startTime;
            outputFile.Write(blockSize, &outputBL->GetBufferList());
            envelope.Process(outData, envOut.data(), thisBlockSize);
            
            vDSP_vabs(envOut.data(), 1, envOut.data(), 1, thisBlockSize);
            vDSP_maxv(envOut.data(), 1, &maxValue, thisBlockSize);
            samplesProcessed += thisBlockSize;
            if (maxValue > linGainToExit)
                sampsBelowThresh = 0;
            else if(!inputFile.IsValid()) {
                sampsBelowThresh += blockSize;
                if (sampsBelowThresh > samplesBelowThreshToExit)
                    break;
            }
            if (thisBlockSize != blockSize) {
                break;
            }
        }
        outputFile.Close();
        Float64 runTime_s = CAHostTimeBase::ConvertToNanos(totalProcessTime)/1.0e9;
        float outFileLen_s = (float)samplesProcessed/(float)fs;
        
        if (verbose)
            printf("BS: %d OutFileLen: %0.2f Process time: %0.4f CPU load: %0.1f\n", blockSize, outFileLen_s, runTime_s, 100.0f*runTime_s/(outFileLen_s));
    }
    catch (CAXException &e) {
        char buf[256];
        printf("Error: %s (%s)\n", e.mOperation, e.FormatError(buf, sizeof(buf)));
        exit(1);
    }
    catch (...) {
        printf("An unknown error occurred\n");
        exit(1);
    }
    return 0;
}
