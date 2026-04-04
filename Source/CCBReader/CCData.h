#pragma once

#include "axmol/axmol.h"

namespace ccb {

class CCData : public ax::Object
{
public:
    CCData(unsigned char* pBytes, unsigned long nSize);
    CCData(CCData* pData);
    ~CCData();

    unsigned char* getBytes() { return m_pBytes; }
    unsigned long getSize() { return m_nSize; }

private:
    unsigned char* m_pBytes = nullptr;
    unsigned long m_nSize = 0;
};

} // namespace ccb
