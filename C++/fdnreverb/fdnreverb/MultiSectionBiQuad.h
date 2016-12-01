//
//  MultiSectionBiQuad.h
//
//  Created by Jay Coggin on 3/5/13.
//
//

#ifndef __MultiSectionBiQuad__
#define __MultiSectionBiQuad__

#include <stdint.h>
#include <vector>

#define NAIVE    1
#define NAIVE_USE_DOUBLE    1

#if NAIVE

class BiQuadDelay
{
public:

#if NAIVE_USE_DOUBLE
    double mX_z1;
    double mX_z2;
    double mY_z1;
    double mY_z2;
#else
    Float32 mX_z1;
    Float32 mX_z2;
    Float32 mY_z1;
    Float32 mY_z2;
#endif

    void Reset() {
        mX_z1 = mX_z2 = mY_z1 = mY_z2 = 0.0;
    }

} ;

#endif  // NAIVE

class MultiSectionBiQuad
{
public:
    MultiSectionBiQuad(const uint32_t numSections, const uint32_t maxFramesPerSlice);
    ~MultiSectionBiQuad();

    // If we write dif eq as y = a0*x + a1*xz_1 + a2*xz_2 - b0*yz_1 - b1*yz_2, then the passed coeffs arg should be a vector of vectors containing blocks of {a0, a1, a2, b0, b1} concatenated togethere
    void Initialize(const double *coeffs);
    void Process(const float *input, float *output, const uint32_t numFrames);
    void Reset();
    int32_t NumberOfSections() const { return mNumSections; }

private:

    int32_t mNumSections;

    std::vector<BiQuadDelay> mDelays;

#if NAIVE_USE_DOUBLE
    std::vector<double> mCoeffs;
#else
    std::vector<Float32> mCoeffs;
#endif  // NAIVE_USE_DOUBLE

};

#endif /* defined(__MultiSectionBiQuad__) */
