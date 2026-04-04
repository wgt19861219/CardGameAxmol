#include "CCBValue.h"

namespace ccb {

// ---- ccColor3BWapper ----

ccColor3BWapper* ccColor3BWapper::create(const ax::Color32& color)
{
    auto* ret = new ccColor3BWapper();
    ret->mColor = color;
    ret->autorelease();
    return ret;
}

// ---- CCBValue ----

CCBValue* CCBValue::create(int nValue)
{
    auto* ret = new CCBValue();
    ret->mValue.nValue = nValue;
    ret->mType = kIntValue;
    ret->autorelease();
    return ret;
}

CCBValue* CCBValue::create(float fValue)
{
    auto* ret = new CCBValue();
    ret->mValue.fValue = fValue;
    ret->mType = kFloatValue;
    ret->autorelease();
    return ret;
}

CCBValue* CCBValue::create(bool vValue)
{
    auto* ret = new CCBValue();
    ret->mValue.nValue = vValue ? 1 : 0;
    ret->mType = kBoolValue;
    ret->autorelease();
    return ret;
}

CCBValue* CCBValue::create(unsigned char byte)
{
    auto* ret = new CCBValue();
    ret->mValue.nValue = byte;
    ret->mType = kUnsignedCharValue;
    ret->autorelease();
    return ret;
}

CCBValue* CCBValue::create(const char* pStringValue)
{
    auto* ret = new CCBValue();
    ret->m_strValue = pStringValue;
    ret->mType = kStringValue;
    ret->autorelease();
    return ret;
}

CCBValue* CCBValue::create(ax::Vector<ax::Object*>* pArrValue)
{
    auto* ret = new CCBValue();
    ret->m_arrValue = pArrValue;
    ret->mType = kArrayValue;
    ret->autorelease();
    return ret;
}

int CCBValue::getIntValue()
{
    AXASSERT(mType == kIntValue, "CCBValue type mismatch");
    return mValue.nValue;
}

float CCBValue::getFloatValue()
{
    AXASSERT(mType == kFloatValue, "CCBValue type mismatch");
    return mValue.fValue;
}

bool CCBValue::getBoolValue()
{
    AXASSERT(mType == kBoolValue, "CCBValue type mismatch");
    return mValue.nValue == 1;
}

unsigned char CCBValue::getByteValue()
{
    AXASSERT(mType == kUnsignedCharValue, "CCBValue type mismatch");
    return (unsigned char)(mValue.nValue);
}

ax::Vector<ax::Object*>* CCBValue::getArrayValue()
{
    AXASSERT(mType == kArrayValue, "CCBValue type mismatch");
    return m_arrValue;
}

const char* CCBValue::getStringValue()
{
    AXASSERT(mType == kStringValue, "CCBValue type mismatch");
    return m_strValue.c_str();
}

} // namespace ccb
