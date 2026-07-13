-- Meta-progression unlock thresholds: the profile's highest level ever
-- reached (across all runs, see core/profile.lua) required before a token
-- type is available in card offer pools, end-of-turn escalation flinging,
-- and the sandbox palette.
--
-- Placeholder values only -- everything is unlocked from the start so this
-- has no effect on current behavior yet. Tune these once level pacing is
-- decided; no code changes needed elsewhere.
return {
  ram              = 0,
  progress         = 0,
  threat           = 0,
  progressNegative = 2,
  threatNegative   = 2,
  drawToHand       = 4,
  drawToDtor       = 4,
  nullify          = 6,
  shuffle          = 6,
  multiplyProgress = 8,
  multiplyThreat   = 8,
  multiplyAll      = 10,
  flip             = 10,
}
