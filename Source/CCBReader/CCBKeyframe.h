#pragma once

#include "axmol/axmol.h"

namespace ccb {

class CCBKeyframe : public ax::Object
{
public:
    CCBKeyframe();
    ~CCBKeyframe();

    static CCBKeyframe* create()
    {
        auto* ret = new CCBKeyframe();
        ret->autorelease();
        return ret;
    }

    ax::Object* getValue() { return mValue; }
    void setValue(ax::Object* pValue);

    float getTime() { return mTime; }
    void setTime(float fTime) { mTime = fTime; }

    int getEasingType() { return mEasingType; }
    void setEasingType(int nEasingType) { mEasingType = nEasingType; }

    float getEasingOpt() { return mEasingOpt; }
    void setEasingOpt(float fEasingOpt) { mEasingOpt = fEasingOpt; }

private:
    ax::Object* mValue = nullptr;
    float mTime = 0.0f;
    int mEasingType = 0;
    float mEasingOpt = 0.0f;
};

} // namespace ccb
