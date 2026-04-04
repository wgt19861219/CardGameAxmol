#include "CCBSequence.h"

namespace ccb {

CCBSequence::CCBSequence() = default;

CCBSequence::~CCBSequence()
{
    AX_SAFE_RELEASE_NULL(mCallbackChannel);
    AX_SAFE_RELEASE_NULL(mSoundChannel);
}

void CCBSequence::setCallbackChannel(CCBSequenceProperty* channel)
{
    AX_SAFE_RELEASE(mCallbackChannel);
    mCallbackChannel = channel;
    AX_SAFE_RETAIN(mCallbackChannel);
}

void CCBSequence::setSoundChannel(CCBSequenceProperty* channel)
{
    AX_SAFE_RELEASE(mSoundChannel);
    mSoundChannel = channel;
    AX_SAFE_RETAIN(mSoundChannel);
}

} // namespace ccb
