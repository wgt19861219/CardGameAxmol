#pragma once

#include "axmol/axmol.h"
#include <string>
#include <vector>

namespace ccb {

// Color wrapper for CCB
class ccColor3BWapper : public ax::Object
{
public:
    static ccColor3BWapper* create(const ax::Color32& color);
    const ax::Color32& getColor() const { return mColor; }

private:
    ax::Color32 mColor = ax::Color32::WHITE;
};

enum
{
    kIntValue,
    kFloatValue,
    kBoolValue,
    kUnsignedCharValue,
    kStringValue,
    kArrayValue
};

class CCBValue : public ax::Object
{
public:
    static CCBValue* create(int nValue);
    static CCBValue* create(bool bValue);
    static CCBValue* create(float fValue);
    static CCBValue* create(unsigned char byte);
    static CCBValue* create(const char* pStr);
    static CCBValue* create(ax::Vector<ax::Object*>* pArr);

    int getIntValue();
    float getFloatValue();
    bool getBoolValue();
    unsigned char getByteValue();
    const char* getStringValue();
    ax::Vector<ax::Object*>* getArrayValue();
    ~CCBValue() { delete m_arrValue; }
    int getType() { return mType; }

private:
    union
    {
        int nValue;
        float fValue;
    } mValue{};
    std::string m_strValue;
    ax::Vector<ax::Object*>* m_arrValue = nullptr;
    int mType = kIntValue;
};

} // namespace ccb
