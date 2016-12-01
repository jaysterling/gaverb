//
//  CircularDelay.h
//
//  Created by Jay Coggin on 9/18/13.
//
//

#ifndef __CircularDelay__
#define __CircularDelay__

#include <vector>
#include <MacTypes.h>

// simple, efficient, sample delay using a circular buffer
class CircularDelay
{
public:
    CircularDelay(UInt32 maxFramesPerSlice, UInt32 maxDelay_samps);
    
    void Reset();
    void SetDelaySamples(UInt32 numSamples);
    void Process(const float* input, float* output, const UInt32 numFrames);
    
private:
    
    void SetReadIndex();

    size_t mBufferLength;
    size_t mDelaySamples;
    std::vector<float> mCircBuffer;
    size_t mWriteIndex;
    size_t mReadIndex;
};

template <typename T>
class ModuloType
{
    T   mModulus;
    T   mVal;
    
public:
    ModuloType() : mModulus(0) {}
    ModuloType(T modulo) : mModulus(modulo) {}
    ModuloType(const ModuloType& x) : mModulus(x.mModulus), mVal(x.mVal) {}
    
    T modulus() const { return mModulus; }
    
    void setModulus(T modulus) {
        mModulus = modulus;
        mVal = 0;
    }
    
    // Pre-increment operator
    T operator++() {
        if(++mVal == mModulus)
            mVal = 0;
        return mVal;
    }
    
    // Post-increment operator
    T operator++(int) {
        T retVal = mVal;
        this->operator++();
        return retVal;
    }
    
    // Pre-decrement operator
    T operator--() {
        if(mVal == 0)
            mVal = mModulus;
        return (--mVal);
    }
    
    // Post-decrement operator
    T operator--(int) {
        T retVal = mVal;
        this->operator--();
        return retVal;
    }
    
    // Assignment operator (modulus)
    T operator=(T x) {
        mVal = (x >= mModulus) ? (x%mModulus) : x;
        return mVal;
    }
    
    // Cast operator
    operator T() {
        return mVal;
    }
    
};

typedef ModuloType<UInt32> ModuloUInt32;

class ElementDelay
{
public:
    ElementDelay(UInt32 maxDelay_samps);
    
    void Reset();
    void SetDelaySamples(UInt32 numSamples);
    float Read();
    void Write(float val);
    
private:
    
    std::vector<float> mCircBuffer;
    ModuloType<int> mWriteIndex;
    ModuloType<int> mReadIndex;
    UInt32 mDelaySamples;
};

#endif /* defined(__CircularDelay__) */
