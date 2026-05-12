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

return animation
