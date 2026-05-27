"""
gen_hero_equip.py — 为 hero_equip.lua 生成 rank 13-23 装备数据

规则：
- Rank 13-16（Orange+1 ~ Orange+4）：5个装备槽（Equip1=0）
- Rank 17-19（Orange+5 ~ Red+1）：4个装备槽（Equip1,2=0）
- Rank 20-23（Red+2 ~ Red+5）：3个装备槽（Equip1,2,3=0）
- 装备ID从 rank 11-12 的装备池中轮换
- 数值按公式递增
"""

import re
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HERO_EQUIP_PATH = os.path.normpath(os.path.join(SCRIPT_DIR, '..', 'hero_equip.lua'))


def parse_file(filepath):
    """行级解析 hero_equip.lua，提取每个英雄的 rank 11 和 rank 12 数据"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    heroes = {}
    current_hero_id = None
    current_rank = None
    current_entry = {}

    for line in lines:
        stripped = line.strip()

        # 匹配英雄块: "  [heroId] = {"
        hero_m = re.match(r'\[(\d+)\]\s*=\s*\{', stripped)
        if hero_m and not line.startswith('    '):
            # 保存前一个英雄
            if current_hero_id is not None and current_entry:
                heroes.setdefault(current_hero_id, {})[current_rank] = current_entry
            current_hero_id = int(hero_m.group(1))
            current_rank = None
            current_entry = {}
            continue

        # 匹配 rank 块: "    [rank] = {"
        rank_m = re.match(r'\[(\d+)\]\s*=\s*\{', stripped)
        if rank_m and line.startswith('    ['):
            # 保存前一个 rank
            if current_rank is not None and current_entry:
                heroes.setdefault(current_hero_id, {})[current_rank] = current_entry
            current_rank = int(rank_m.group(1))
            current_entry = {}
            continue

        # 匹配字段: '      ["key"] = value,'
        field_m = re.match(r'\["([^"]+)"\]\s*=\s*(.*)', stripped)
        if field_m and current_rank is not None:
            key = field_m.group(1)
            value = field_m.group(2).rstrip(',').strip()
            current_entry[key] = value

        # rank 闭合: "    }" or "    },"
        if re.match(r'\},?\s*$', stripped) and line.startswith('    }'):
            if current_rank is not None and current_entry:
                heroes.setdefault(current_hero_id, {})[current_rank] = current_entry
                current_rank = None
                current_entry = {}

    return heroes, lines


def get_equip_pool(rank_data):
    """从 rank 数据中提取非零装备 ID 及其名称"""
    pool = []
    for i in range(1, 7):
        eid = rank_data.get(f'Equip{i} ID', '0')
        ename = rank_data.get(f'Equip{i}', '"0"')
        if eid != '0':
            pool.append((ename, eid))
    return pool


def generate_rank_entry(hero_id, hero_name, rank, type_str,
                         equip_pool, r12_data):
    """生成一个 rank 条目的 Lua 代码"""
    if rank <= 16:
        filled_slots = [2, 3, 4, 5, 6]
    elif rank <= 19:
        filled_slots = [3, 4, 5, 6]
    else:
        filled_slots = [4, 5, 6]

    offset = rank - 12

    r12_gs = float(r12_data.get('GS', '0').strip('"'))
    r12_lv = float(r12_data.get('LV', '0').strip('"'))
    r12_lvreq = int(r12_data.get('LvReq', '88'))
    equip_level = round(rank * 0.2, 1)
    lvreq = r12_lvreq + offset * 3
    gs = round(r12_gs * (1 + offset * 0.12), 2)
    lv = round(r12_lv * (1 + offset * 0.15))

    pool_size = len(equip_pool)
    lines = []
    lines.append(f'    [{rank}] = {{')
    lines.append(f'      ["Desc"] = "{hero_name}{rank}",')

    for slot in range(1, 7):
        if slot in filled_slots:
            idx = (slot + offset - 1) % pool_size
            ename, eid = equip_pool[idx]
            lines.append(f'      ["Equip{slot}"] = {ename},')
            lines.append(f'      ["Equip{slot} ID"] = {eid},')
        else:
            lines.append(f'      ["Equip{slot}"] = "0",')
            lines.append(f'      ["Equip{slot} ID"] = 0,')

    lines.append(f'      ["EquipLevel"] = {equip_level},')
    lines.append(f'      ["GS"] = "{gs}",')
    lines.append(f'      ["Hero_ID"] = {hero_id},')
    lines.append(f'      ["Hero_Name"] = "{hero_name}",')
    lines.append(f'      ["Init1 ID"] = 0,')
    lines.append(f'      ["Init2 ID"] = 0,')
    lines.append(f'      ["Init3 ID"] = 0,')
    lines.append(f'      ["Init4 ID"] = 0,')
    lines.append(f'      ["Init5 ID"] = 0,')
    lines.append(f'      ["Init6 ID"] = 0,')
    lines.append(f'      ["LV"] = "{int(lv)}",')
    lines.append(f'      ["LvReq"] = {lvreq},')
    lines.append(f'      ["Quality"] = {rank},')
    lines.append(f'      ["Type"] = {type_str}')
    lines.append(f'    }}')

    return '\n'.join(lines)


def main():
    print(f"读取: {HERO_EQUIP_PATH}")
    heroes, lines = parse_file(HERO_EQUIP_PATH)
    print(f"解析到 {len(heroes)} 个英雄")

    # 验证数据
    for hid in sorted(heroes.keys()):
        ranks = heroes[hid]
        if 12 not in ranks:
            print(f"  英雄 {hid} 没有 rank 12, 有 rank {sorted(ranks.keys())}")

    # 生成新数据
    hero_gen_data = {}
    for hero_id in sorted(heroes.keys()):
        ranks = heroes[hero_id]
        r11 = ranks.get(11)
        r12 = ranks.get(12)
        if not r12:
            print(f"  英雄 {hero_id} 没有 rank 12 数据，跳过")
            continue

        hero_name = r12.get('Hero_Name', f'Hero{hero_id}').strip('"')
        type_str = r12.get('Type', 'LSTR("HERO_EQUIP.STRENGTH")')

        pool = []
        if r11:
            pool.extend(get_equip_pool(r11))
        pool.extend(get_equip_pool(r12))
        seen = set()
        unique_pool = []
        for ename, eid in pool:
            if eid not in seen:
                seen.add(eid)
                unique_pool.append((ename, eid))
        pool = unique_pool if unique_pool else get_equip_pool(r12)

        entries = []
        for rank in range(13, 24):
            entry = generate_rank_entry(hero_id, hero_name, rank, type_str,
                                        pool, r12)
            entries.append(entry)
        hero_gen_data[hero_id] = entries

    print(f"为 {len(hero_gen_data)} 个英雄生成数据")

    # 修改文件：在行级插入
    # 找到每个英雄的 rank 12 闭合行，在其后插入新数据
    output = []
    i = 0
    inserted_heroes = set()

    while i < len(lines):
        line = lines[i]
        output.append(line)

        # 检测 rank 12 闭合行:
        # "    }" 行，且紧接下一行是 "  }," 或 "  }"（英雄块结束）
        # 且前面几行内有 "Quality" = 12
        if i + 1 < len(lines) and line.rstrip() == '    }':
            next_line = lines[i + 1].rstrip()
            is_last_rank = (next_line == '  },' or next_line == '  }')
            if is_last_rank:
                # 检查前面几行是否有 Quality = 12
                has_quality_12 = False
                for j in range(max(0, i - 5), i):
                    if '"Quality"] = 12' in lines[j]:
                        has_quality_12 = True
                        break

                if has_quality_12:
                    # 确定是哪个英雄——往前找最近的 "  [heroId] = {"
                    hero_id = None
                    for j in range(i - 1, -1, -1):
                        m = re.match(r'  \[(\d+)\]\s*=\s*\{', lines[j])
                        if m:
                            hero_id = int(m.group(1))
                            break

                    if hero_id and hero_id in hero_gen_data and hero_id not in inserted_heroes:
                        # rank 12 闭合 } 需要加逗号
                        output[-1] = '    },\n'
                        # 插入新 rank 数据
                        for entry_text in hero_gen_data[hero_id]:
                            output.append(entry_text + ',\n')
                        # 最后一个条目去掉逗号
                        output[-1] = output[-1].rstrip(',\n') + '\n'
                        inserted_heroes.add(hero_id)

        i += 1

    with open(HERO_EQUIP_PATH, 'w', encoding='utf-8') as f:
        f.writelines(output)

    print(f"写入完成！插入了 {len(inserted_heroes)} 个英雄的 rank 13-23 数据")


if __name__ == '__main__':
    main()
