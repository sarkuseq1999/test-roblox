local CombatMath = {}

-- Damage with simple armor mitigation and a small variance band.
function CombatMath.ComputeDamage(rawDamage, armor, rng)
	rng = rng or Random.new()
	local mitigation = armor / (armor + 100)
	local mitigated = rawDamage * (1 - mitigation)
	local variance = rng:NextNumber(0.85, 1.15)
	return math.max(1, math.floor(mitigated * variance + 0.5))
end

-- XP scaling: full reward in a +/-3 level band, then falls off.
function CombatMath.ScaleXP(baseXP, playerLevel, monsterLevel)
	local diff = monsterLevel - playerLevel
	local mult
	if diff >= -3 and diff <= 3 then
		mult = 1.0
	elseif diff > 3 then
		mult = 1.0 + math.min(diff - 3, 5) * 0.10
	else
		mult = math.max(0.05, 1.0 + diff * 0.18)
	end
	return math.max(1, math.floor(baseXP * mult))
end

-- Group XP split with a small group bonus, capped at 6 members.
function CombatMath.SplitGroupXP(totalXP, memberCount)
	memberCount = math.clamp(memberCount, 1, 6)
	local bonus = 1 + (memberCount - 1) * 0.08
	return math.max(1, math.floor(totalXP * bonus / memberCount))
end

return CombatMath
