WAIT UNTIL SHIP:UNPACKED.
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
print "Automatic engine control script loaded".

local ramJetEngines is List().
local jetEngines is List().

for engine in ship:engines
{
	if engine:HasModule("ModuleEnginesAJERamjet")
	{
		ramJetEngines:add(engine:GetModule("ModuleEnginesAJERamjet")).
	}
	
	if engine:HasModule("ModuleEnginesAJEJet")
	{
		jetEngines:add(engine:GetModule("ModuleEnginesAJEJet")).
	}
}

local adjustmentStep is 0.5.

if ramJetEngines:LENGTH > 0 or jetEngines:LENGTH > 0
{
	print "managing engines".
	local ramJetEngineSample is ramJetEngines[0].
	local maxRamJetEngineTemp is ramJetEngineSample:GetHiddenField("maxEngineTemp") - 2.
	local ramJetEngineThrustLimit is 100.
	
	local jetEngineSample is jetEngines[0].
	local maxJetEngineTemp is jetEngineSample:GetHiddenField("maxEngineTemp") - 2.
	local jetEngineThrustLimit is 79.5.
	
	until false
	{
		if ramJetEngineThrustLimit <> ramJetEngineSample:GetField("thrust limiter")
		{
			set ramJetEngineThrustLimit to ramJetEngineSample:GetField("thrust limiter").
		}

		local ramJetEngineTemp is ramJetEngineSample:GetField("eng. internal temp").
		if ramJetEngineTemp >= maxRamJetEngineTemp
		{
			set ramJetEngineThrustLimit to max(0, ramJetEngineThrustLimit - adjustmentStep).
			for engine in ramJetEngines
			{
				engine:SetField("thrust limiter", ramJetEngineThrustLimit).
			}
		}

		local jetEngineTemp is jetEngineSample:GetField("eng. internal temp").
		if jetEngineTemp >= maxJetEngineTemp
		{
			set jetEngineThrustLimit to max(0, jetEngineThrustLimit - adjustmentStep).
			for engine in jetEngines
			{
				engine:SetField("thrust limiter", jetEngineThrustLimit).
				if engine:GetField("thrust") < 1
				{
					if engine:HasEvent("shutdown engine")
					{
						engine:DoEvent("shutdown engine").
						print "shutting down jet engine".
					}
				}
			}
		}

		wait 0.05.
	}
	print "stopping script".
}
else
{
	print "No engines detected, stopping script".
}