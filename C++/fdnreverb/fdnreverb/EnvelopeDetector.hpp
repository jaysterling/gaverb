//
//  EnvelopeDetector.hpp
//  fdnreverb
//
//  Created by Jay Coggin on 2/4/15.
//  Copyright © 2015 Jay Coggin. All rights reserved.
//

#ifndef _fdnreverb_EnvelopeDetector_
#define _fdnreverb_EnvelopeDetector_

#include <stdio.h>
#include <MacTypes.h>

typedef enum {
    kEnvelopeDetectorMode_Peak,
    kEnvelopeDetectorMode_MeanSquared,
    kEnvelopeDetectorMode_SimpleOnePoleLP
} EnvelopeDetectorMode;

class EnvelopeDetector
{
public:
    EnvelopeDetector(UInt32 sampleRate);
    
    // setting true means a call to either setter of attack or release will set both, and upon setting true , attack time will be picked
    void                        LinkAttackAndReleaseTimes(bool makeLinked);
    void                        SetAttackTime(float attack_ms);
    void                        SetReleaseTime(float release_ms);
    void                        SetMode(EnvelopeDetectorMode mode) {mMode = mode;}
    void                        SetTimeConstantInterpretationAnalog(bool asAnalog);
    void                        Prime(float primeValue) {mPrevEnvelope = primeValue;}
    
    void                        Reset();
    void                        Process(const float* input, float* output, UInt32 numFrames, Boolean* holdFlags = NULL);
    
private:
    
    const float                 mSampleRate;
    float                       mAttackConstant;
    float                       mReleaseConstant;
    float                       mAttackTime_ms;
    float                       mReleaseTime_ms;
    EnvelopeDetectorMode        mMode;
    bool                        mTCAsAnalog;
    float                       mPrevEnvelope;
    bool                        mTCsLinked;
};

#endif /* defined(_fdnreverb_EnvelopeDetector_) */
