local ed = ed
local TB_range_interval = 150
local mirror_time = 12
local TBult_atk_cd = 1.5
local LancerMirror2_update = function(basefunc, unit, dt)
  unit.mDuration = unit.mDuration - dt
  if unit.mDuration <= 0 then
    unit:die()
  else
    basefunc(unit, dt)
  end
end
local LancerMirror_update = function(basefunc, unit, dt)
  unit.mDuration = unit.mDuration - dt
  if unit.mDuration <= 0 then
    unit:die()
  else
    basefunc(unit, dt)
  end
end
local function createMirrorClone(caster, position)
  local proto = {
    _tid = 147,
    _level = caster.level or 1,
    _stars = caster.stars,
    _rank = caster.rank
  }
  local config = {
    is_monster = true,
    estimate_rank = true,
    hp_mod = caster.config.hp_mod or 1,
    dps_mod = caster.config.dps_mod or 1
  }
  local LancerMirror = ed.UnitCreate(proto, caster.camp, config)
  local bid = 89
  local binfo = ed.lookupDataTable("Buff", nil, bid)
  local buff = LancerMirror:addBuff(binfo, caster)
  LancerMirror.mDuration = mirror_time
  LancerMirror.update = override(LancerMirror.update, LancerMirror_update)
  LancerMirror:setDeathWithEffectOrNot(true)
  LancerMirror.direction = caster.direction
  local locationtb = {
    position[1],
    position[2]
  }
  ed.engine:summonUnit(LancerMirror, locationtb, caster)
  return LancerMirror
end
local function skillult_takeEffectAt(basefunc, skill, location, source)
  basefunc(skill, location, source)
end
local function skillatk3_takeEffectOn(basefunc, skill, target)
  basefunc(skill, target)
  local caster = skill.caster
  if not caster:isAlive() then
    return
  end
  local LancerMirror = createMirrorClone(caster, {
    target.position[1] + 70 * caster.direction,
    target.position[2]
  })
  if LancerMirror.position[1] > 799 or LancerMirror.position[1] < 1 then
    LancerMirror.position[1] = target.position[1] - 70 * caster.direction
  end
  caster.LancerMirror3 = LancerMirror
end
local function skillatk2_takeEffectAt(basefunc, skill, location, source)
  basefunc(skill, location, source)
  local caster = skill.caster
  local LancerMirror1 = createMirrorClone(caster, {
    location[1] + caster.direction * 40,
    location[2] + caster.direction * 30
  })
  local LancerMirror2 = createMirrorClone(caster, {
    location[1] + caster.direction * 40,
    location[2] - caster.direction * 30
  })
  caster.position[1] = caster.position[1] - caster.direction * 40
  caster.LancerMirror21 = LancerMirror1
  caster.LancerMirror22 = LancerMirror2
end
local skillult_power = function(basefunc, self, source, target)
  local power, i = basefunc(self, source, target)
  local attack_counter = self.attack_counter
  if attack_counter == 2 then
    return 0, i
  end
  return power, i
end
local hero_die = function(basefunc, hero, killer)
  if hero.LancerMirror1 and hero.LancerMirror1:isAlive() then
    hero.LancerMirror1:die()
  end
  if hero.LancerMirror21 and hero.LancerMirror21:isAlive() then
    hero.LancerMirror21:die()
  end
  if hero.LancerMirror22 and hero.LancerMirror22:isAlive() then
    hero.LancerMirror22:die()
  end
  if hero.LancerMirror3 and hero.LancerMirror3:isAlive() then
    hero.LancerMirror3:die()
  end
  if hero.LancerMirror4 and hero.LancerMirror4:isAlive() then
    hero.LancerMirror4:die()
  end
  if hero.LancerMirrorult and hero.LancerMirrorult:isAlive() then
    hero.LancerMirrorult:die()
  end
  basefunc(hero, killer)
end
local skillminSQ = 18225
local function skillatk_start(basefunc, self, target)
  local info = self.info
  if do_battle_log then
    btlog("%s began to cast %s --> %s", self.caster:display(), self:display(), target and target:display() or "nil")
  end
  self.target = target
  self:selectTarget(target)
  self.cd_remaining = info.CD
  self.casting = true
  self.attack_counter = 0
  local caster = self.caster
  local distanceSQ = (self.target.position[1] - caster.position[1]) ^ 2
  self.originfo = self.info
  if distanceSQ > skillminSQ then
    self.info = ed.wraptable(self.originfo, {
      ["AOE Shape"] = "rectangle",
      ["Shape Arg1"] = 231,
      ["Shape Arg2"] = 150
    })
  else
    self.info = ed.wraptable(self.originfo, {
      ["AOE Shape"] = "halfcircle",
      ["Shape Arg1"] = 140,
      ["Shape Arg2"] = false
    })
  end
  if distanceSQ > skillminSQ then
    self:startPhase(1)
  else
    self:startPhase(2)
  end
  self.is_update = true
  local caster = self.caster
  caster.global_cd = info["Global CD"]
  caster:setMP(caster.mp - info["Cost MP"] * (1 - caster.attribs.CDR / 100))
  if caster.actor then
    local effect_name = info["Launch Effect"]
    if effect_name then
      caster.actor:addEffect(effect_name, -1)
    end
  end
end
local skillatk_onPhaseFinished = function(basefunc, self)
  self:finish()
end
local skillatk3_createProjectile = function(basefunc, skill)
  local projectile = basefunc(skill)
  local target = projectile.skill.target
  if not target then
    return
  end
  projectile:enableTrack(target)
  return projectile
end
local function skillult_onAttackFrame(basefunc, skill)
  local originfo = skill.info
  local attack_counter = skill.attack_counter
  if attack_counter >= 2 and attack_counter <= 6 then
    skill.info = ed.wraptable(originfo, {
      ["Shape Arg1"] = 231
    })
    basefunc(skill)
    skill.info = originfo
  else
    skill.info = ed.wraptable(originfo, {
      ["Shape Arg1"] = 300
    })
    basefunc(skill)
    skill.info = originfo
  end
  if skill.attack_counter == 2 and skill.caster:isAlive() then
    local caster = skill.caster
    local LancerMirror = createMirrorClone(caster, {
      caster.position[1],
      caster.position[2]
    })
    caster.LancerMirrorult = LancerMirror
  end
end
local skillatk_finish = function(basefunc, skill)
  skill.originfo = skill.info
  basefunc(skill)
end
local function init_hero(hero)
  hero.die = override(hero.die, hero_die)
  local skillult = hero.skills.Lancer_ult
  if skillult then
    skillult.takeEffectAt = override(skillult.takeEffectAt, skillult_takeEffectAt)
    skillult.power = override(skillult.power, skillult_power)
    skillult.onAttackFrame = override(skillult.onAttackFrame, skillult_onAttackFrame)
  end
  local skillatk2 = hero.skills.Lancer_atk2
  if skillatk2 then
    skillatk2.takeEffectAt = override(skillatk2.takeEffectAt, skillatk2_takeEffectAt)
  end
  hero.info.mDuration = mirror_time
  local skillatk = hero.skills.Lancer_atk
  if skillatk then
    skillatk.onPhaseFinished = override(skillatk.onPhaseFinished, skillatk_onPhaseFinished)
    skillatk.start = override(skillatk.start, skillatk_start)
    skillatk.finish = override(skillatk.finish, skillatk_finish)
  end
  local skillatk3 = hero.skills.Lancer_atk3
  if skillatk3 then
    skillatk3.takeEffectOn = override(skillatk3.takeEffectOn, skillatk3_takeEffectOn)
    skillatk3.createProjectile = override(skillatk3.createProjectile, skillatk3_createProjectile)
  end
  return hero
end
return init_hero
