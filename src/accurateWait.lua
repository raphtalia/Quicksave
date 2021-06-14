local RunService = game:GetService("RunService")

return function(dt)
	dt = math.max(0, dt)
	local left = dt

	while left > 0 do
		left = left - RunService.Heartbeat:Wait()
	end

	return dt - left
end