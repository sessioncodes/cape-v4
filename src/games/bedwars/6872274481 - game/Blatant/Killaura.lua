local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ExtraReach
	local ReachBoost
	local ChargeTime
	local UpdateRate
	local AngleSlider
	local VerticalAngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local NoGround
	local AutoDelay
	local PredictMovement
	local PredictionFactor
	local HitChance
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local FaceMode
	local FaceSmooth
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local RequireSword
	local TargetFOV
	local IgnoreDead
	local IgnoreInvisible
	local PrioritizeLowHealth
	local MaxHealthFilter
	local MinHealthFilter
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local lastHitChance = true
	local function rollHitChance()
		if HitChance.Value >= 100 then return true end
		lastHitChance = math.random(1, 100) <= HitChance.Value
		return lastHitChance
	end

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		if NoGround.Enabled and entitylib.character.RootPart.Velocity.Y < -1 then return false end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		if RequireSword.Enabled and store.hand.toolType ~= 'sword' then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	local function getEffectiveSwingRange()
		return SwingRange.Value + (ExtraReach.Enabled and ReachBoost.Value or 0)
	end

	local function getEffectiveAttackRange()
		return AttackRange.Value + (ExtraReach.Enabled and ReachBoost.Value or 0)
	end

	local function applyPrediction(rootPart)
		if not PredictMovement.Enabled then return rootPart.Position end
		local velocity = rootPart.AssemblyLinearVelocity
		return rootPart.Position + (velocity * PredictionFactor.Value)
	end

	local function filterByHealth(plrs)
		if not (MaxHealthFilter.Enabled or MinHealthFilter.Enabled or PrioritizeLowHealth.Enabled) then return plrs end
		local filtered = {}
		for _, v in plrs do
			local hum = v.Character and v.Character:FindFirstChildOfClass('Humanoid')
			if hum then
				local hp = hum.Health
				if MaxHealthFilter.Enabled and hp > MaxHealthFilter.Value then continue end
				if MinHealthFilter.Enabled and hp < MinHealthFilter.Value then continue end
				table.insert(filtered, v)
			else
				table.insert(filtered, v)
			end
		end
		if PrioritizeLowHealth.Enabled then
			table.sort(filtered, function(a, b)
				local ha = a.Character and a.Character:FindFirstChildOfClass('Humanoid')
				local hb = b.Character and b.Character:FindFirstChildOfClass('Humanoid')
				return (ha and ha.Health or math.huge) < (hb and hb.Health or math.huge)
			end)
		end
		return filtered
	end

	local function filterByFOV(plrs)
		if not TargetFOV.Enabled or TargetFOV.Value >= 360 then return plrs end
		local camPos = gameCamera.CFrame.Position
		local camLook = gameCamera.CFrame.LookVector
		local filtered = {}
		for _, v in plrs do
			if not v.RootPart then continue end
			local dir = (v.RootPart.Position - camPos).Unit
			local angle = math.deg(math.acos(camLook:Dot(dir)))
			if angle <= TargetFOV.Value / 2 then
				table.insert(filtered, v)
			end
		end
		return filtered
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, fake)
					debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, fake)

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local swingR = getEffectiveSwingRange()
						local attackR = getEffectiveAttackRange()

						local plrs = entitylib.AllPosition({
							Range = swingR,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if IgnoreInvisible.Enabled then
							plrs = (function()
								local visible = {}
								for _, v in plrs do
									if v.Character and v.Character:FindFirstChild('Humanoid') then
										local root = v.Character:FindFirstChild('HumanoidRootPart')
										if root and root.Transparency < 1 then
											table.insert(visible, v)
										end
									else
										table.insert(visible, v)
									end
								end
								return visible
							end)()
						end

						if IgnoreDead.Enabled then
							plrs = (function()
								local alive = {}
								for _, v in plrs do
									local hum = v.Character and v.Character:FindFirstChildOfClass('Humanoid')
									if not hum or hum.Health > 0 then
										table.insert(alive, v)
									end
								end
								return alive
							end)()
						end

						plrs = filterByHealth(plrs)
						plrs = filterByFOV(plrs)

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								local targetPos = applyPrediction(v.RootPart)
								local delta = (targetPos - selfpos)
								local horizontalDelta = delta * Vector3.new(1, 0, 1)
								local angle = math.acos(localfacing:Dot(horizontalDelta.Unit))

								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								if VerticalAngleSlider.Value < 180 then
									local verticalAngle = math.deg(math.atan2(delta.Y, horizontalDelta.Magnitude))
									if math.abs(verticalAngle) > VerticalAngleSlider.Value then continue end
								end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > attackR and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										local delayTime = meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.11
										if AutoDelay.Enabled then
											delayTime = math.max(delayTime, 1 / UpdateRate.Value)
										end
										AnimDelay = tick() + delayTime
										bedwars.SwordController:playSwordEffect(meta, false)
										if meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > attackR then continue end

								if not rollHitChance() then continue end

								local actualRoot = v.Character.PrimaryPart
								if actualRoot then
									local predictedPos = applyPrediction(actualRoot)
									local dir = CFrame.lookAt(selfpos, predictedPos).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									AttackRemote:FireServer({
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = predictedPos},
											selfPosition = {value = pos}
										}
									})
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local target = attacked[1].Entity.RootPart.Position
						local vec = target * Vector3.new(1, 0, 1)
						local currentPos = entitylib.character.RootPart.Position
						local targetCFrame = CFrame.lookAt(currentPos, Vector3.new(vec.X, currentPos.Position.Y + 0.001, vec.Z))
						if FaceSmooth.Enabled then
							entitylib.character.RootPart.CFrame = entitylib.character.RootPart.CFrame:Lerp(targetCFrame, FaceSmooth.Value / 10)
						else
							entitylib.character.RootPart.CFrame = targetCFrame
						end
					end

					task.wait(#attacked > 0 and #attacked * 0.02 or 1 / UpdateRate.Value)
				until not Killaura.Enabled
			else
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, bedwars.Knit)
				debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
				Attacking = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance', 'Health', 'FOV'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ExtraReach = Killaura:CreateToggle({
		Name = 'Extra reach boost',
		Tooltip = 'Adds additional studs to both swing and attack range'
	})
	ReachBoost = Killaura:CreateSlider({
		Name = 'Reach boost',
		Min = 0,
		Max = 20,
		Default = 5,
		Suffix = ' studs',
		Visible = false
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max horizontal angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	VerticalAngleSlider = Killaura:CreateSlider({
		Name = 'Max vertical angle',
		Min = 1,
		Max = 180,
		Default = 180,
		Suffix = '°'
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 5
	})
	HitChance = Killaura:CreateSlider({
		Name = 'Hit chance',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	NoGround = Killaura:CreateToggle({
		Name = 'No ground attack',
		Tooltip = 'Stops attacking while falling'
	})
	AutoDelay = Killaura:CreateToggle({
		Name = 'Auto delay',
		Tooltip = 'Matches attack delay to update rate'
	})
	PredictMovement = Killaura:CreateToggle({
		Name = 'Movement prediction',
		Tooltip = 'Predicts target movement for better hit rate'
	})
	PredictionFactor = Killaura:CreateSlider({
		Name = 'Prediction factor',
		Min = 0,
		Max = 2,
		Default = 0.15,
		Decimal = 100,
		Visible = false
	})
	TargetFOV = Killaura:CreateSlider({
		Name = 'Target FOV',
		Min = 1,
		Max = 360,
		Default = 360,
		Suffix = '°'
	})
	IgnoreDead = Killaura:CreateToggle({
		Name = 'Ignore dead',
		Tooltip = 'Skips targets with 0 health'
	})
	IgnoreInvisible = Killaura:CreateToggle({
		Name = 'Ignore invisible',
		Tooltip = 'Skips invisible targets'
	})
	PrioritizeLowHealth = Killaura:CreateToggle({
		Name = 'Prioritize low HP',
		Tooltip = 'Sorts targets by lowest health first'
	})
	MaxHealthFilter = Killaura:CreateSlider({
		Name = 'Max target HP',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = ' hp'
	})
	MinHealthFilter = Killaura:CreateSlider({
		Name = 'Min target HP',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = ' hp'
	})
	RequireSword = Killaura:CreateToggle({
		Name = 'Strict sword check',
		Tooltip = 'Only attacks when explicitly holding a sword'
	})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({
		Name = 'Face target',
		Function = function(callback)
			FaceMode.Object.Visible = callback
			FaceSmooth.Object.Visible = callback
		end
	})
	FaceMode = Killaura:CreateDropdown({
		Name = 'Face mode',
		List = {'Instant', 'Smooth'},
		Default = 'Instant',
		Darker = true,
		Visible = false
	})
	FaceSmooth = Killaura:CreateSlider({
		Name = 'Face smoothness',
		Min = 1,
		Max = 10,
		Default = 5,
		Darker = true,
		Visible = false
	})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)