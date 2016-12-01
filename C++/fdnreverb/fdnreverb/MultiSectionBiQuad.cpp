//
//  MultiSectionBiQuad.cpp
//
//  Created by Jay Coggin on 3/5/13.
//
//

#include "MultiSectionBiQuad.h"
#include <sys/param.h>

using namespace std;

MultiSectionBiQuad::MultiSectionBiQuad(const uint32_t numSections, const uint32_t maxFramesPerSlice)
: mNumSections(numSections)
{
    mDelays.resize(numSections);
    #if NAIVE_USE_DOUBLE
        mCoeffs = vector<double> (mNumSections*5, 0.0);
    #else
        mCoeffs = vector<Float32> (mNumSections*5, 0.0);
    #endif
    for (uint32_t sec = 0; sec < numSections; sec++) {
        mCoeffs.at(0 + 5*sec) = 1.0;
    }
    
    Reset();

}
MultiSectionBiQuad::~MultiSectionBiQuad()
{
}


// If we write dif eq as y = a0*x + a1*xz_1 + a2*xz_2 - b0*yz_1 - b1*yz_2, then the passed coeffs arg should be a concatenated groups of 5 coeffs containing {a0, a1, a2, b0, b1}, with the number of these groups determing the number of sections
void MultiSectionBiQuad::Initialize(const double *coeffs)
{
#if NAIVE_USE_DOUBLE
    for (uint32_t i = 0 ; i < mNumSections*5; i++) {
        mCoeffs.at(i) = coeffs[i];
    }
#else
    for (UInt32 i = 0 ; i < mNumSections*5; i++) {
        mCoeffs.at(i) = static_cast<Float32>(coeffs[i]);
    }
#endif

}

void MultiSectionBiQuad::Reset()
{
    for (uint32_t i = 0; i < mNumSections; i++) {
        mDelays.at(i).Reset();
    }
}

void MultiSectionBiQuad::Process(const float *input, float *output, const uint32_t numFrames)
{
    for (uint32_t frame = 0; frame < numFrames; frame++) {
        
#if NAIVE_USE_DOUBLE
        double secInput = static_cast<double>(input[frame]);
#else
        Float32 secInput = input[frame];
#endif
        
        for (uint32_t sec = 0; sec < mNumSections; sec++) {
            
            uint32_t offset = sec*5;
            
            BiQuadDelay *del = &mDelays.at(sec);
            
#if NAIVE_USE_DOUBLE
            double y;
#else
            Float32 y;
#endif
            y = mCoeffs.at(offset)*secInput + mCoeffs.at(offset + 1)*del->mX_z1 + mCoeffs.at(offset + 2)*del->mX_z2 - mCoeffs.at(offset + 3)*del->mY_z1 - mCoeffs.at(offset + 4)*del->mY_z2;
            
            del->mX_z2 = del->mX_z1;
            del->mX_z1 = secInput;
            del->mY_z2 = del->mY_z1;
            del->mY_z1 = y;
            
            secInput = y;
        }
        
#if NAIVE_USE_DOUBLE
        output[frame] = static_cast<float>(secInput);
#else
        output[frame] = secInput;
#endif
    }
}
