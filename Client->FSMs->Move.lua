--!optimize 2
--!nocheck

--[[
Move finite finite state machine to go along with the omnidirectional camera
- jump coyote time
- jump buffering
- half implemented slope movement
- half implemented collide and slide
- smooth velocity
- scalable with lots of optimisations
- superstates represented by UpdateGrounded and UpdateAirborne
]]

local key_left_shift=Enum.KeyCode.LeftShift
local key_space=Enum.KeyCode.Space
local worksp=workspace
local W,A,S,D=Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D
local cam=workspace.CurrentCamera
local flat_vec=vector.create(1,0,1)
local up_vec = vector.create(0,1,0)
local vec_zero=vector.zero
local RawCall=require(script.Parent.Parent.Help.RawCall)
local SetInstanceNewIndex =	RawCall.instance_newindex -- equivalent to script.Name = foo
local GetCFrameIndex = RawCall.cframe_index
local GetInstanceIndex = RawCall.instance_index -- equivalent to local foo = script.Name (the dot operator)
local rp=RaycastParams.new()
rp.FilterType=Enum.RaycastFilterType.Exclude

local Types=require(script.Parent.Parent.Info.Types)
type loaded=Types.loaded
type char=Types.char

local function IsOnSlope(groundNormal):boolean
	--dot(up_vec,groundNormal)==1 when flat. so 1-dot(...) is "how flat is it".
	--0 when "perfectly" flat respective ot epsilon
	--compared to small eps to account for floating point err
	return 1-vector.dot(up_vec,groundNormal)>.000001
end
local function GetProjVec(vec, normal): Vector3
	return vec - (normal * vector.dot(vec,normal))
end
return function(loaded:loaded,char:char)
	local root=char.Root
	local leg_bottom=root.LegBottom
	local leg_top=root.LegTop
	rp.FilterDescendantsInstances={char}
	
	local skin=.025
	local radius=root.Size.Y*.5 --assumes root is a sphere shape part
	local grounded_ray_dir:vector=vector.create(0,-vector.magnitude(leg_top.WorldPosition-leg_bottom.WorldPosition)-skin,0)
	
	--// state
	--INPUT
	local iX,iZ=0,0
	local w_down=false
	local a_down=false
	local s_down=false
	local d_down=false
	local space_down=false
	--PHYS
	--// general
	local pos	
	local vel=vec_zero
	local has_wasd=false
	local has_no_wasd=false
	local prev_vel_horiz=vector.zero
	local prev_ground_intersect_y
	local MAX_SPEED=10
	local OMEGA_ACCEL=3 -- response speed, higher = more response
	local OMEGA_DECEL=4
	-- falling
	local fall_terminal_vel=-60
	local fall_grav=-10
	local fall_y_vel_value=0
	local jump_buffer_allowance=.25
	local timer_coyote=0
	local timestamp_jump_request --jump buffering
	local COYOTE_TIME=.4
	-- falling and grounded
	local can_step_up=true --prevents jitter up bug
	--jumping
	local jump_dynamic_y_velo=0
	--//c
	local jump_y_velo=16
	local jump_grav=-30

	local function SmoothVel(v, target, dt, omega)
		--lerp to target vel with alpha as exp smoothening frame rate indepdencence
		return v:Lerp(target,1-math.exp(-omega*dt))
	end
	local function UpdateHorizVel(dt)
		if has_wasd then
			local cam_CF=GetInstanceIndex(cam,'CFrame')
			local rv=GetCFrameIndex(cam_CF,'RightVector')
			local lv=GetCFrameIndex(cam_CF,'LookVector')
			local minus_iZ=-iZ --optimisation probably unnecessary,to be safe
			-- gets noramlised "raw" flat move vector below
			-- scales vector X by whether it's forward or back input (minus iz)
			-- etc
			local dir=vector.normalize(vector.create((lv.X*minus_iZ)+(rv.X*iX),0,(lv.Z*minus_iZ)+(rv.Z*iX)))
			local vel_target=dir*MAX_SPEED
			--// smoothens prev_vel to target by exp lerp. we store prev_vel_horiz
			--because the vel in "General" is only the accumulator vel which gets reset end of every frame
			prev_vel_horiz = SmoothVel(prev_vel_horiz, vel_target, dt, OMEGA_ACCEL)
		else
			prev_vel_horiz = SmoothVel(prev_vel_horiz, vec_zero, dt, OMEGA_DECEL)
		end
		vel+=(prev_vel_horiz*dt) --update to accumulator vel
	end	
	local function UpdateFlatCollideSlide():vector
		--[[
		1. cast out from original vel
		2. if detected, project the leftover vel to the flat wall normal
			also slice the vel by the distance to teh wall to ensure snug against it
			we use flat normal, otherwise plr would slide y change which we dont wnat
		3. if vel sliding, cast out with projected to detect any wall colls while sliding
			if wall coll, then slice the vel with a skin width to alleviate pahsing thru
		4. update vel
		]]
		local v_out=vel
		local c=worksp:Spherecast(pos,radius,vel,rp)
		if c then
			v_out=vector.normalize(vel)*(c.Distance-skin)
			local n_flat=vector.normalize(c.Normal*flat_vec)	
			local v_proj=GetProjVec(vel-v_out,n_flat)
			local c2=worksp:Spherecast(pos,radius,v_proj,rp)
			if c2 then
				v_out=vector.normalize(vel)*(c2.Distance-skin)
			else
				v_out=v_proj
			end
		end
		vel=v_out
	end

	--dont wrap grounded. incurs extra fn overhead
	local function UpdateGrounded(dt:number)
		local ray=worksp:Raycast(GetInstanceIndex(leg_top,'WorldPosition'),grounded_ray_dir,rp)
		if not ray then return 'Falling' end		
		if space_down then return 'Jumping' end
	
		-- handle all vel here for a single source of truth, and for clean scope to ray, etc
		local is_on_slope=IsOnSlope(ray.Normal)
		if is_on_slope then
			if has_wasd then
				local cam_CF=GetInstanceIndex(cam,'CFrame')
				local rv=GetCFrameIndex(cam_CF,'RightVector')
				local lv=GetCFrameIndex(cam_CF,'LookVector')
				local minus_iZ=-iZ
				local unnormalized_dir=vector.create((lv.X*minus_iZ)+(rv.X*iX),0,(lv.Z*minus_iZ)+(rv.Z*iX))
				local unnormalized_proj_dir=GetProjVec(unnormalized_dir,ray.Normal)::vector
				local slope_vel_dir=vector.normalize(unnormalized_proj_dir)
				local slope_vel_mag=5*dt
				local slope_vel=(slope_vel_dir*slope_vel_mag)
				
				local projected_vel_ray=worksp:Raycast(
					leg_bottom.WorldPosition,
					slope_vel,
					rp
				)
				if projected_vel_ray then
					-- will touch ground this frame
					-- so snap to ground to prevent sinking thru
					local to_ground_exactly=slope_vel_dir*projected_vel_ray.Distance*dt	
					vel+=to_ground_exactly
					
					--// slope is buggy. what u would do is
					-- find the leftover horiz vel for this frame then add it to unstuck the char
				else
					vel+=slope_vel
				end
			end
		else
			UpdateHorizVel(dt)

			--// ground align
			local new_y=ray.Position.Y
			if can_step_up and prev_ground_intersect_y then
				local diff=new_y-prev_ground_intersect_y
				-- if diff negative then cant step up
				-- if diff positive then cant step up
				-- only if diff 0 then can step up
				-- and ignore stepup if prev_state==falling, Falling sets the flag
				if diff>0 then
					vel+=vector.create(0,diff*(1-math.exp(-5*dt)),0) --smoothly exp smooth it up by alpha
				else
					prev_ground_intersect_y=new_y
				end				
			else
				can_step_up=true
				--DONT TEP up this frame. it leads tobug. we already let the falling landed logic snap us to it
				prev_ground_intersect_y=new_y
			end
		end
	end
	local function UpdateAirborne(dt:number)
		timer_coyote=math.max(0,timer_coyote-dt)
		if space_down and timer_coyote>0 then
			timer_coyote=0 --consume anyway
			return 'Jumping'
		end
		
		UpdateHorizVel(dt)
	end
	local t_states={ --arrs used for perf speed access memory etc, instead of tables. Enter,Exit,Update
		Falling={
			function(state_prev:string?)
				if state_prev~='Jumping' then
					print('state prev wasnt jump it was',state_prev)
					timer_coyote=COYOTE_TIME --i.e. coyote time
				end
				can_step_up=false
			end,
			function(state_new:string?)
				timer_coyote=0 --consume regardless
				fall_y_vel_value=0
				timestamp_jump_request=nil --make sure it's nil
			end,
			function(dt:number)
				local s_new:string?=UpdateAirborne(dt)
				if s_new then return s_new end
				
				-- update vertical velocity
				fall_y_vel_value=fall_y_vel_value+(fall_grav*dt) --integrating grav (so called Euler Integration)
				fall_y_vel_value=math.max(fall_y_vel_value,fall_terminal_vel) --clamp to terminal falling vel
				local y_change_vec=vector.create(0,fall_y_vel_value*dt,0) --make actual fall displacement vec

				-- raycast to check landing, only need to by what htey would have fallen this frame (y_change_vec)
				local ray = worksp:Raycast(
					GetInstanceIndex(leg_bottom,'WorldPosition'),
					y_change_vec,
					rp
				)
				if ray then
					-- snap down exactly to ground
					-- dist of exact snap is ray.Distance
					vel+=vector.create(0,-ray.Distance,0)
					
					--// checking for coyote jump (given the time diff between leaving a ledge and jumping is below 
					-- jump buffer allowance)
					if timestamp_jump_request and os.clock()-timestamp_jump_request<=jump_buffer_allowance then
						return 'Jumping'
					else
						-- switch to walking/idling on landed
						if has_wasd then
							return 'Walking'
						else
							return 'Idling'
						end
					end
				else
					if space_down and not timestamp_jump_request then
						--// set jump buffer request IF we dont have it already
						-- if we have it already, ignore, to prevent unintentional space-spam input stuff
						timestamp_jump_request=os.clock()
					end
					
					-- still falling, apply to vel accumulator
					vel+=y_change_vec
				end
			end,
		},
		Jumping={
			function()
				jump_dynamic_y_velo=jump_y_velo
			end,
			function()
				jump_dynamic_y_velo=0
			end,
			function(dt)
				UpdateAirborne(dt)
				
				-- update vertical velocity
				jump_dynamic_y_velo += jump_grav * dt --euler integration again like falling but go up
				-- get actual displacement (scalar) since we dont need to ray up for our purposes
				-- unlike falling. if u want to add ceiling coll then u need a raycast  by y_change vec though
				local y_change:number = jump_dynamic_y_velo * dt

				-- apply vertical movement BEFORE checking for falling
				vel += vector.create(0, y_change, 0)

				-- switch state if reached the descending part of parabolic trajectory
				if y_change < 0 then
					return 'Falling'
				end
			end,
		},
		Idling={
			function()
				
			end,
			function()
				
			end,
			function(dt)
				local state_new=UpdateGrounded(dt)
				--if UpdateGrounded superstate switched, then it has priority over below switch (e.g. go to falling)
				if state_new then return state_new end
				--self explanatory, if has_wasd from iX iZ (set in UpdateGrouded fn) then go wal
				if has_wasd then return 'Walking' end 
			end,
		},
		Walking={
			function()

			end,
			function()

			end,
			function(dt)
				--look in Idling comments
				local state_new=UpdateGrounded(dt)
				if state_new then return state_new end
				if has_no_wasd then return 'Idling' end
			end,
		},
	}
	
	local state --current state
	local state_update_fn --current state's update fn (for cache, for perf)
	local state_exit_fn --what would be current state's exit fn (for cache, perf)
	
	-- initial switch (inlined bec it's not worth having a fn. would only make it look bad)
	do
		state='Idling'
		local arr_ref=t_states.Idling
		state_exit_fn=arr_ref[2]
		state_update_fn=arr_ref[3]
	end
	
	return {
		--// set key_down or off variables here. more perf than polling UIS:IsKeydown(enum.key...)
		--etc. more perf to just poll the variable
		-- more responsive too, with inputbegan
		-- bec InputBegan,ended, fire exactly when the key changes state.
		-- also expose these for the batcher in "FSMs" to take and batch
		InputBegan = function(key, input_type)
			if key == W then
				w_down = true
			elseif key == A then
				a_down = true
			elseif key == S then
				s_down = true
			elseif key == D then
				d_down = true
			elseif key==key_space then
				space_down=true
			end
		end,
		InputEnded = function(key, input_type)
			if key == W then
				w_down = false
			elseif key == A then
				a_down = false
			elseif key == S then
				s_down = false
			elseif key == D then
				d_down = false
			elseif key==key_space then
				space_down=false
			end
		end,
		Update=function(dt:number)		
			--local a=os.clock()
			--gets the root Position property in a more perf way even considering fn overhead,
			--by abusing select and access stuff (look in RawCall helper module)
			pos=GetInstanceIndex(root,'Position')
			--// setting input state from any keypress detected
			iX = (d_down and 1 or 0) + (a_down and -1 or 0)
			iZ = (s_down and 1 or 0) + (w_down and -1 or 0)
			has_wasd=iX~=0 or iZ~=0
			has_no_wasd=not has_wasd --convient to also have this instead of if not has_wasd..., and a microop
			
			
			--// call current state's update fn. if it returns a string (either from its superstate)
			--update fns like UpdateGrounded or UpdateAirborne, we do the actual switch logic
			--best fsm perf u can make on roblox
			local state_new:string?=state_update_fn(dt)
			if state_new then -- switch. avoid fn overhead here.
				local a=os.clock()
				-- exit prev
				state_exit_fn(state_new)

				-- enter new
				local arr=t_states[state_new]
				arr[1](state) --"state" passed in is state_prev
				state_exit_fn=arr[2]
				state_update_fn=arr[3]
				state=state_new
				print(os.clock()-a,'switchto',state_new)
			end
			-- ignore the one frame delay
			-- if u try "fixing" it by updating in same frame ull introduce jitter lag and other problems
			-- treat it as intentional, because it's an inevitable result of fsm update switchimplementation
						
			--// update coll and slide to detect any colls
			UpdateFlatCollideSlide()
			
			--opt. vec_dot(v,v) is squared mag. squared mag is perf faster than vec_mag(). so used vec_dot
			if vector.dot(vel,vel)>0 then
				local new_pos=pos+vel

				-- facing_dir must have a flat vel to use cf_lookat on in a predictable way
				local facing_dir=vel*flat_vec --1,0,1
				if facing_dir~=vec_zero then --prevents nan. check if nonzero vec without sqrt expensive
					facing_dir=vector.normalize(facing_dir) --renormalise for cf_lookat consistency
					
					char:PivotTo(CFrame.lookAt(new_pos,new_pos+facing_dir))
				else
					-- just pivot to new_pos with respect to existing rotation
					char:PivotTo(CFrame.new(new_pos)*GetCFrameIndex(GetInstanceIndex(root,'CFrame'),'Rotation'))
				end	
			end
			--// reset frame accumulators
			vel=vec_zero 
		end,
		Wipe=function()
			
		end,
	}
end
