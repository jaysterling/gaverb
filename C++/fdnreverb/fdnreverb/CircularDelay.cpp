//
//  CircularDelay.cpp
//
//  Created by Jay Coggin on 9/18/13.
//
//

#include <math.h>
#include <sys/param.h>

#include "CircularDelay.h"


CircularDelay::CircularDelay(UInt32 maxFramesPerSlice, UInt32 maxDelay_samps) :
mBufferLength(maxFramesPerSlice + maxDelay_samps),
mDelaySamples(0),
mCircBuffer(mBufferLength),
mWriteIndex(0),
mReadIndex(0)
{
    Reset();
}

void CircularDelay::SetReadIndex()
{
    if (static_cast<int>(mWriteIndex) - static_cast<int>(mDelaySamples) < 0) {
        mReadIndex = static_cast<size_t>((static_cast<int>(mWriteIndex) + static_cast<int>(mBufferLength) - static_cast<int>(mDelaySamples)));
    }
    else {
        mReadIndex = mWriteIndex - mDelaySamples;
    }
}

void CircularDelay::SetDelaySamples(UInt32 numSamples)
{
    if (numSamples <= mBufferLength) {
        mDelaySamples = numSamples;
        SetReadIndex();
    }
}

void CircularDelay::Reset()
{
    fill(mCircBuffer.begin(), mCircBuffer.end(), 0.0f);
    mWriteIndex = 0;
    SetReadIndex();
}

void CircularDelay::Process(const float* input, float* output, const UInt32 numFrames)
{
    size_t writeFramesLeft = numFrames;
    
    // get number to copy over this time, could be all, could be less if we're nearing the end
    size_t writeThisTime = MIN(writeFramesLeft, mBufferLength - mWriteIndex);
    memcpy(&mCircBuffer.at(mWriteIndex), input, writeThisTime*sizeof(float));
    
    // that many less to do this time
    writeFramesLeft -= writeThisTime;
    
    // move our write pointer, wrap if necessary
    mWriteIndex += writeThisTime;
    mWriteIndex = mWriteIndex >= mBufferLength ? mWriteIndex - mBufferLength : mWriteIndex;
    
    // if there's still more to copy, do it and increment the write index again
    if (writeFramesLeft)
    {
        memcpy(&mCircBuffer.at(mWriteIndex), &input[numFrames - writeFramesLeft], writeFramesLeft*sizeof(float));
        mWriteIndex += writeFramesLeft;
    }
    
    // basically the same process for reading
    size_t readFramesLeft = numFrames;
    
    size_t readThisTime = MIN(readFramesLeft, mBufferLength - mReadIndex);
    memcpy(output, &mCircBuffer.at(mReadIndex), readThisTime*sizeof(float));
    
    readFramesLeft -= readThisTime;
    
    mReadIndex += readThisTime;
    mReadIndex = mReadIndex >= mBufferLength ? mReadIndex - mBufferLength : mReadIndex;
    
    if (readFramesLeft)
    {
        memcpy(&output[numFrames - readFramesLeft], &mCircBuffer.at(mReadIndex), readFramesLeft*sizeof(float));
        mReadIndex += readFramesLeft;
    }
}

ElementDelay::ElementDelay(UInt32 maxDelay_samps) :
mCircBuffer(maxDelay_samps+4),
mWriteIndex(maxDelay_samps+4),
mReadIndex(maxDelay_samps+4),
mDelaySamples(0)
{
    Reset();
}

void ElementDelay::Reset()
{
    std::fill(mCircBuffer.begin(), mCircBuffer.end(), 0.0f);
    mWriteIndex = 0;
    SetDelaySamples(mDelaySamples);
}

void ElementDelay::SetDelaySamples(UInt32 numSamples)
{
//    printf("Trying to set delay to %d, size=%d\n", numSamples, mCircBuffer.size());
    if (numSamples <= mCircBuffer.size()) {
        mDelaySamples = numSamples;
        mReadIndex = mWriteIndex;
        for (int i = 0; i < numSamples+1; i++)  // go 1 farther than num samples because we read before we write
            --mReadIndex;
    }
//    printf("Delaysamps=%d W=%d R=%d\n", mDelaySamples, (int)mWriteIndex, (int)mReadIndex);
}

float ElementDelay::Read()
{
    return mCircBuffer[mReadIndex++];
}

void ElementDelay::Write(float val)
{
    mCircBuffer[mWriteIndex++] = val;
}

