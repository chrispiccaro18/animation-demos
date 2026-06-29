local animation = {}

function animation.lerp(a, b, t)
  return a + (b - a) * t
end

function animation.expDecay(a, b, k, dt)
  return b + (a - b) * math.exp(-k * dt)
end

function animation.springDecay(pos, vel, target, stiffness, damping, dt)
  local force = (target - pos) * stiffness - vel * damping
  vel = vel + force * dt
  pos = pos + vel * dt
  return pos, vel
end

function animation.degreesToRadians(degrees)
  return degrees * math.pi / 180
end

-- Normalized oscillation in [0, 1] for a given phase (phase = time * speed + offset).
-- Change this function to remap all pulse easing in one place.
function animation.pulseValue(phase)
  local s = math.sin(phase) * 0.5 + 0.5
  -- regular stine
  -- return s
  -- squared stine
  -- return s * s
  -- smoothstep
  -- return s * s * (3 - 2 * s)
  -- triangle wave
  local p = (phase / (2 * math.pi)) % 1
  return p < 0.5 and p * 2 or (2 - p * 2)
end

return animation
