#pragma once

#include "axmol/axmol.h"
#include "CCBSequenceProperty.h"
#include <string>

namespace ccb {

class CCBSequence : public ax::Object
{
public:
    CCBSequence();
    ~CCBSequence();

    static CCBSequence* create()
    {
        auto* ret = new CCBSequence();
        ret->autorelease();
        return ret;
    }

    float getDuration() { return mDuration; }
    void setDuration(float fDuration) { mDuration = fDuration; }

    CCBSequenceProperty* getCallbackChannel() { return mCallbackChannel; }
    void setCallbackChannel(CCBSequenceProperty* channel);

    CCBSequenceProperty* getSoundChannel() { return mSoundChannel; }
    void setSoundChannel(CCBSequenceProperty* channel);

    const char* getName() { return mName.c_str(); }
    void setName(const char* pName) { mName = pName; }

    int getSequenceId() { return mSequenceId; }
    void setSequenceId(int nId) { mSequenceId = nId; }

    int getChainedSequenceId() { return mChainedSequenceId; }
    void setChainedSequenceId(int nId) { mChainedSequenceId = nId; }

private:
    float mDuration = 0.0f;
    std::string mName;
    int mSequenceId = 0;
    int mChainedSequenceId = 0;
    CCBSequenceProperty* mCallbackChannel = nullptr;
    CCBSequenceProperty* mSoundChannel = nullptr;
};

} // namespace ccb
