//
//  EnvelopeDetector.cpp
//  fdnreverb
//
//  Created by Jay Coggin on 2/4/15.
//  Copyright © 2015 Jay Coggin. All rights reserved.
//

#include "EnvelopeDetector.hpp"
#include <Accelerate/Accelerate.h>

#define ANALOG_TC   -0.43533393574791066201247090699309     // log10(36.7%)
#define DIGITAL_TC  -2.0                                    // log10(1%)

EnvelopeDetector::EnvelopeDetector(UInt32 sampleRate) :
mSampleRate(sampleRate),
mMode(kEnvelopeDetectorMode_SimpleOnePoleLP),
mTCAsAnalog(false),
mPrevEnvelope(0),
mTCsLinked(false)
{
    SetAttackTime(0);
    SetReleaseTime(0);
}

void EnvelopeDetector::LinkAttackAndReleaseTimes(bool makeLinked)
{
    mTCsLinked = makeLinked;
    if (mTCsLinked) SetReleaseTime(mAttackTime_ms);
}

void EnvelopeDetector::SetTimeConstantInterpretationAnalog(bool asAnalog)
{
    mTCAsAnalog = asAnalog;
    SetAttackTime(mAttackTime_ms);
    SetReleaseTime(mReleaseTime_ms);
}

void EnvelopeDetector::SetAttackTime(float attack_ms)
{
    mAttackTime_ms = attack_ms;
    
    if(mTCAsAnalog) mAttackConstant = exp(ANALOG_TC/(mAttackTime_ms * mSampleRate * 0.001));
    else mAttackConstant = exp(DIGITAL_TC/(mAttackTime_ms * mSampleRate * 0.001));
    
    if (mTCsLinked) {
        mReleaseConstant = mAttackConstant;
        mReleaseTime_ms = mAttackTime_ms;
    }
}

void EnvelopeDetector::SetReleaseTime(float release_ms)
{
    mReleaseTime_ms = release_ms;
    
    if(mTCAsAnalog) mReleaseConstant = exp(ANALOG_TC/(mReleaseTime_ms * mSampleRate * 0.001));
    else mReleaseConstant = exp(DIGITAL_TC/(mReleaseTime_ms * mSampleRate * 0.001));
    
    if (mTCsLinked) {
        mAttackConstant = mReleaseConstant;
        mAttackTime_ms = mReleaseTime_ms;
    }
}

void EnvelopeDetector::Reset()
{
    mPrevEnvelope = 0;
}

void EnvelopeDetector::Process(const float* input, float* output, UInt32 numFrames, Boolean* holdFlags)
{
    switch (mMode) {
        case kEnvelopeDetectorMode_MeanSquared:
            vDSP_vsq(input, 1, output, 1, numFrames);
            break;
        case kEnvelopeDetectorMode_Peak:
            vDSP_vabs(input, 1, output, 1, numFrames);
            break;
        case kEnvelopeDetectorMode_SimpleOnePoleLP:
        default:
            if (input != output) memcpy(output, input, numFrames*sizeof(float));
            break;
    }
    
    for (int i = 0; i < numFrames; i++) {
        if (holdFlags && holdFlags[i] == true)
            output[i] = mPrevEnvelope;
        else if(output[i] > mPrevEnvelope)
            output[i] = mAttackConstant * (mPrevEnvelope - output[i]) + output[i];
        else
            output[i] = mReleaseConstant * (mPrevEnvelope - output[i]) + output[i];
        
        mPrevEnvelope = output[i];
    }
}
