#pragma once

#include "axmol/axmol.h"
#include "CCBKeyframe.h"
#include <string>

namespace ccb {

class CCBSequenceProperty : public ax::Object
{
public:
    CCBSequenceProperty();
    ~CCBSequenceProperty();

    static CCBSequenceProperty* create()
    {
        auto* ret = new CCBSequenceProperty();
        ret->autorelease();
        return ret;
    }

    const char* getName() { return mName.c_str(); }
    void setName(const char* pName) { mName = pName; }

    int getType() { return mType; }
    void setType(int nType) { mType = nType; }

    ax::Vector<CCBKeyframe*>& getKeyframes() { return mKeyframes; }

private:
    std::string mName;
    int mType = 0;
    ax::Vector<CCBKeyframe*> mKeyframes;
};

} // namespace ccb
