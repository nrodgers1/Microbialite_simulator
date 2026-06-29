#Importing all required packages


import Pkg

# List of required packages
packages = ["Agents", "LinearAlgebra", "Random", "StatsBase", "GLMakie"]

# Install any packages that aren't already present
for p in packages
    Pkg.add(p)
end






# Import the Agents package for agent-based modeling functionality
# Import LinearAlgebra for matrix and vector operations
using Agents, LinearAlgebra




# Import Random for generating random numbers and sequences
using Random

# Import StatsBase for statistical functions and tools
using StatsBase
    

#Needed for Video Creation    
using  GLMakie





#helper function for counting
function count_at_least(iter, threshold)
    count_val = 0
    for _ in iter # Iterate through the collection
        count_val += 1
        if count_val > threshold
            return true # Found more than the threshold, no need to count further
        end
    end
    return false # Did not find more than the threshold
end

#helper function for finding max height
function find_max_height(A)
    num_rows = size(A, 2)
    for r in num_rows:-1:1  # Iterate from the last row upwards
        if any(x != 0 for x in A[:, r]) # Check if any element in the row is non-zero
            return r
        end
    end
    return 0 # If no non-zero values are found in the entire array
end




    
    




#Define the Agents types in the simulations
#Set the dimension and Space type with GridAgent{2}, {2} for 2d and {3} for 3d 

# Define a Sediment agent type
# This agent represents sediment particles in the simulation
@agent struct Sediment(GridAgent{2})
    # No additional properties defined for sediment
end

# Define a MicrobeMat agent type
# This agent represents an approximation of microbial mats that can grow on surfaces and precipitate
@agent struct MicrobeMat(GridAgent{2})
   # No additional properties defined for microbial mats
end






#Agent Stepping function using Julia multiple Dispatch, same function name for each agent type 
#Function which acts on the Sediment particles making them move or stick

#Preference for left/right motion in order [left,right] 
#Modify for 3D
const weights_side= pweights([0.5,0.5])

#Preference for down/up motion in order [down,up] 
#Want probability down to be greater than up so particles on average drift down 
const weights_vert = pweights([0.9,0.1])




function agent_step!(sediment::Sediment, model)




    #Call RNG from model 
    rng = abmrng(model)
    
    #Get the position of the agent
    agent_pos = sediment.pos

    #Extract the attraction and stability distance from the model

    attraction_dist = model.attraction_dist
    stability_dist = model.stability_dist
        
    #Find the nearby locations within the attaction distance
    nearby = nearby_positions(agent_pos, model, attraction_dist)

    
    #Find the locations which are solid to potentially stick near
    solid_nearby_locs = [loc for loc in nearby if model.solid[loc...] != 0]

    #If any solid locations were found, shuffle them, to prevent bias in model
    if !isempty(solid_nearby_locs)
    # Use shuffle! for in-place shuffling
        shuffle!(rng, solid_nearby_locs)
    end


    
    #Start Looping through solid locations for places to stick 
    for loc in solid_nearby_locs


      
            #Search within stabilty distance of identified location
            stability_search = nearby_positions(loc, model, stability_dist)

            #Create a containers for locations and weights
            targets_loc = Tuple{Int, Int}[]
            weights = Float64[]

            # Counter for number of valid targets
            ntargets = 0

           #Loop through nearby positions
            for place in (stability_search)

            
                #Check if potential location is empty 
                if model.solid[place...]==0

                    #Add location to list of potential places 
                    push!(targets_loc, place)


                    
                    #Loop through neighbours to check if they are full, want to stick near solid objects 
                    local_positions = nearby_positions(place, model, 1)
                    local_weight = 0

                    for p in local_positions
                        #Update local weights with count of non-zero neighbours
                        #Can update this function have any weight rule
                        local_weight = local_weight + (model.solid[p...] >0)
                    end
                    #Add local_weights to weights list
                    push!(weights, local_weight)
                    #weights[ntargets] = local_weight
                    ntargets += 1
                end 
            end 


            #Check weights list is not empty 
            if ntargets > 0

                #Convert weights to probablities
                probabilities = weights ./ sum(weights)
                
                #Select a location with given probability using Julia Sample function
                choice = sample(rng, targets_loc, pweights(probabilities))



                
                #Set the location to non-zero value represting a solid, actual value represents colour or another property for visualisation
                model.solid[choice...] = 2


            
                #Remove the sediment agent
                remove_agent!(sediment, model)
               
                #Check if space is empty and add MicrobeMat agent according to recolonisation probability 
                if isempty(choice, model) && (model.recolonisation_prob > rand(rng))
                    add_agent!(choice, MicrobeMat, model)
                    end
                #End the function evaluation here if managed to find a place to stick 
                return
            end 
        end

    #If a place to stick is not found move onto the movement steps 

 

   

    #Function to pick walk direction and set biases of direction
    #Weights should sum to 1 as they are probabilities
    #The size of the steps could also be drawn from a distubtion but constant step size for simplicty


    
    #Pick the direction by sampling from [-1,1] using the given weights
    dir_side = sample(rng, [-1,1], weights_side)

    dir_vert = sample(rng, [-1,1], weights_vert)

    #Extract the stepsize from model in each direction
    #This could be drawn from a distubtion but should an integer for the grid spacing 
    
    down_speed = model.downspeed
    sideways_speed = model.sidespeed

    
    #Execute the particle step with the Agents.jl walk function
    #Checking the space to move to is empty
    walk!(sediment, (dir_side*sideways_speed,dir_vert*down_speed), model;
        ifempty = true
        )

    #Finally do some checks to see if agent needs to be removed


    #First check the agent is not at the top of the grid for array bounds before the check 
    if agent_pos[2] != model.height

    #Check if the agent has either reached the bottom of the grid or walked into the solid and remove if this is the case     
    if agent_pos[2]== 1 || model.solid[agent_pos[1], agent_pos[2] + 1] != 0
        #remove the agent
        remove_agent!(sediment, model)
        #Terminate the function
        return
    end
    end  


    

    

end





#Multiple Dispatch Function to step the MicrobeMat Agents




function agent_step!(microbe::MicrobeMat, model)

    #Call RNG from model 
    rng = abmrng(model)
    

    #Start by checking if the agent should be randomly removed
    #Probablity that the agent is randomly removed
    if model.remove_probs > rand(rng)
    #Delete agent and terminate the loop
    remove_agent!(microbe, model)
    return
    end
    
    #Get the position of the agent
    agent_pos = microbe.pos


    #Get the direct neeighbours of the agent
    neighbours = nearby_positions(agent_pos, model, 1)
    #Initialise counts of the neighbours and if they are full 
    solid_count::Int = 0
    total_count::Int = 0 
    
    blocking_count::Int = 0
    
    #Create containers for locastions agent can grow to and weights
    empty = Tuple{Int, Int}[]
    weight = Float64[]

    #Loop throgh the neighbours 
    for place in (neighbours)

        #Increase the total_count of all neighbouring spaces by 1
        total_count = total_count + 1

        #Check if the neighbour is solid 
        if model.solid[place...] >0
        #Count number of solid neighbours
        solid_count = solid_count + 1



        #Update the count of blocking neighbours         
        if place[2] >= agent_pos[2] 
        blocking_count += 1
            end

        #If space is not filled compute probablity to grow there     
        else 

            #Add location to empty space list
            push!(empty, place)

            
            #Compute the height difference assuming Manhattan or Euclidean distance here
            height_difference = place[2] - agent_pos[2]

            # Map height difference -1, 0, 1 to array indices 1, 2, 3
            #Array is set in model intialisation and gives preference for growing downwards, sideways or upwards
            weight_index = height_difference + 2

            

            #Add weights to weight list 
            push!(weight, model.precip_weights_down_side_up[weight_index])
        end 
    
        
    end
    

    


    #If all the neighbours of the microbe are solid remove it. 
    if solid_count == total_count
    remove_agent!(microbe, model)
        return


    

        
    #Allow microbe growth
    else 
        #Ensure Growth is actaully favourable and not just default emptry region
        weight_sum = sum(weight)
       if isempty(empty)==false && (weight_sum > 1e-9)

            #Convert weights to probability
            weight = weight/weight_sum 

            #Sample weights 
            choice = sample(rng, empty, pweights(weight))


    #Compute exposure factor if conical behaviour is being induced            
        
     exposure_factor = 1.0 / (blocking_count + 1)^model.conical_scale 


    #Set flag to true for overhang prevention logic  
                
    is_stable_location = true 


    #Begin Overhang prevention logic
                

    if model.prevent_overhang == true 


    target_x, target_y = choice

    is_on_floor = (target_y <=2)

    # Check the spot directly below the target
    has_vertical_support = (target_y > 1) && (model.solid[target_x, target_y - 1] > 0)

    # Check the spots diagonally below (left-down and right-down)
    # This allows the cone to widen by 1 pixel for every 1 pixel of height (45 degrees)
    has_diagonal_support = (target_y > 1) && (
        (target_x > 1 && model.solid[target_x - 1, target_y - 1] > 0) || 
        (target_x < model.width && model.solid[target_x + 1, target_y - 1] > 0)
        )

    
    #reset flag to required state
    is_stable_location = is_on_floor || has_vertical_support || has_diagonal_support


                end 



     
        
    #If the space is empty check the 
    if is_stable_location && isempty(choice, model)  && (model.precip_probs*exposure_factor > rand(rng))

        #Fill solid with Int to represent properties for visulisation
        model.solid[choice...] = 3
       
        add_agent!(choice, MicrobeMat, model)
    end
        end
    end
end







#Function which steps the world forwards and adds new sediment to the simulation 
function world_step!(model)
    #Call RNG from model 
    rng = abmrng(model)
    
    #Can in theory make any of the parameters a function of time at this point
    #Any parameter could be called and updated here if you like


    #sed_ment_rate = model.sediment_amplitude

    t= abmtime(model) 

    # Precompute angular frequencies
    sediment_ω = 2π / model.period_control_T
    microbe_ω  = 2π / (model.precip_period_scaling * model.period_control_T)

    # Helper inline functions
    periodic_value(mode::Symbol, x) = mode === :max_cos  ? max(0, cos(x)) :
                                  mode === :abs  ? abs(cos(x))   :
                                  mode === :cos2 ? cos(x)^2      :
                                  mode === :constant ? 1.0           :
                                  error("Unknown periodic mode: $mode")


    sediment_amplitude = round(Int, model.sediment_amplitude *
                      periodic_value(model.sediment_periodic_mode, t * sediment_ω))

    model.precip_probs = model.precip_amplitude * periodic_value(model.precip_periodic_mode,(t + model.precip_period_offset) * microbe_ω)



    #Set how near the edges of the grid particles should be released
    min_col::Int = 1
    max_col::Int = model.width 

    

    if mod(t, 10)==0
            model.max_height = find_max_height(model.solid)
            #println(model.max_height)
        end



    # Compute a safe random offset
    down_offset = model.downspeed > 1 ? rand(1:(model.downspeed - 1)) : 0

    input_row = min(model.height - 5, 10*model.downspeed + model.max_height) - down_offset
    

    #Get range of potential releases 
    candidate_cols = min_col:max_col

    input_row_offsets = input_row .+ (-5:5)
    potential_positions = [(col, row) for col in candidate_cols for row in input_row_offsets]

    #Check for valid release positions
    #potential_positions = [(col, input_row) for col in candidate_cols]

    valid_positions = [
        pos for pos in potential_positions
        if model.solid[pos...] == 0 && isempty(pos, model)
    ]


    #Get number of particles to add if space is shorter than expected number 
    num_to_add = min(sediment_amplitude, length(valid_positions))
    
    if num_to_add > 0
        # Sample 'num_to_add' unique positions from 'valid_positions'
        # Using shuffle! and taking the first num_to_add is efficient if num_to_add << length(valid_positions)
            #shuffle!(rng, valid_positions)[1:num_to_add]
        chosen_positions = shuffle!(rng, valid_positions)[1:num_to_add]

        # Add sediment agents at the chosen locations, should be empty from previous checks
        for pos in chosen_positions
            add_agent!(pos, Sediment, model)
        end
    end
end 










#Using a Mutable Struct so that code runs faster due to type information provided
#All parameters can be modifed as the simulation runs however they need to respect the type defintions
#All parameter defaults are listed below, with explaination given 

Base.@kwdef mutable struct WorldParameters
    #Width of the simulation
    width::Int = 1000
    #Height of the simulation
    height::Int = 400
    #Type of intial conditions can be :base_line, :rough, :localised, :mound, :triangle details can be changed by function modfiaction
    initial_solid_setup_type::Symbol = :base_line
    #Speed that particles step in the vertical direction
    downspeed::Int = 3
    #Speed that particles step in the horizontal direction, want to keep as 1 so particles can hit ever point if doing single point release
    sidespeed::Int = 1
    #Probability that a living microbial mat agent grows
    precip_amplitude::Float64 = 0.08
    #This precip_probs is dyanmically update through the simulations if using periodic microbial activty
    precip_probs::Float64 = 0.8
    #Probability that a living microbial mat agent is removed at each time step
    remove_probs::Float64 = 0.02
    #Preferences for microbial mat growth directions
    precip_weights_down_side_up::Vector{Int} = [0, 1, 1]
    #Sediment Rate maximum value
    sediment_amplitude::Int = 50
    #Parameter which is related to the period of the sediment rate
    period_control_T::Float64 = 200
    #Parameter which sets how to scale the microbe growth period relative to the sedimentation rate
    precip_period_scaling::Float64 = 1
    #Parameter which sets how to offset the microbe growth osciliations relative to the sedimentation rate
    precip_period_offset::Float64 = 50 
    #Stability distance of the DLA
    stability_dist::Int = 15
    #Attraction distance of the DLA
    attraction_dist::Int = 15
    #How much to weight growing out of the tips to create conical strcuture,
    #Set to zero for no-bias and higher, values for more bias, this will rescale growth so growth rates need to increase in tandem
    conical_scale::Float64 = 0
    #Intialisation of the solid matrix to store the state
    solid::Matrix{UInt8} = zeros(0, 0)
    #Choice of the distance matrix
    distance_metric::Symbol = :euclidean#options should be :euclidean, :manhattan for physical behaviour; :chebyshev will also work but beware of corners
    initial_microbe_density::Float64 = 0.9 #Propotion of intial substrate which contains a microbe
    #Recolonisation Probability - Pararmeter which sets how likely micorobe to appear at site of newly landed sediment
    recolonisation_prob::Float64 = 0.5
    max_height::Int = 100
    #Flags to choose behaviour of perodic function
    sediment_periodic_mode::Symbol = :abs # e.g. :max_cos, :cos2, :abs, :constant
    precip_periodic_mode::Symbol =  :abs # e.g. :max_cos, :cos2, :abs, :constant
    #Flag to set if overhanging horizontal behaviour is allowed, prevents mushroom type strctures  
    prevent_overhang::Bool = false
    initial_setup_index::Int = 1
    
end



#
function makeworld(
initial_params::WorldParameters;
seed::Union{Nothing, Int} = nothing, rng::AbstractRNG = Random.default_rng()
)


setup_options = [:base_line, :rough, :localised, :mound, :triangle]
initial_params.initial_solid_setup_type = setup_options[initial_params.initial_setup_index]


    setup_opts = [:base_line, :rough, :localised, :mound, :triangle]
    
    # We use a 'get' or a check to see if we are in "Interactive Mode"
    # This allows the slider to drive the choice
    if hasfield(WorldParameters, :initial_setup_index)
        initial_params.initial_solid_setup_type = setup_opts[initial_params.initial_setup_index]
    end

    

space = GridSpaceSingle((initial_params.width, initial_params.height); 
                        periodic = (true,false), 
                        metric = initial_params.distance_metric)

# Initialise solid matrix
solid_setup = zeros(UInt8, initial_params.width, initial_params.height)

# Determine bottom layer / roughness
if initial_params.initial_solid_setup_type == :base_line
    solid_setup[:, 1] .= 1

elseif initial_params.initial_solid_setup_type == :rough
    h = round.(Int, 5*sin.(collect(1:initial_params.width)*(2*pi)/300) + abs.(1*randn(initial_params.width)))
    for a in 1:initial_params.width
        solid_setup[a, 1:h[a]] .= 1
    end

elseif initial_params.initial_solid_setup_type == :localised
    #Integer Division
    side = initial_params.width ÷ 2
    #Specfic region for overhangs       
    solid_setup[(side -5):(side + 5), 1] .= 1
       

elseif initial_params.initial_solid_setup_type == :mound
    # Define the center and width of your mound
    #Integer Division        
    center_x = initial_params.width ÷ 2
    mound_half_width = 75  # Total width of 150
    mound_height = 10      # Height of the center peak in pixels

    for x in (center_x - mound_half_width):(center_x + mound_half_width)
        # Ensure we are within grid bounds
        if 1 <= x <= initial_params.width
            # Parabolic equation: y = H * (1 - (dist/W)^2)
            # This creates a smooth mound instead of a sharp triangle
            dist = abs(x - center_x)
            h = round(Int, mound_height * (1 - (dist / mound_half_width)^2))
            
            # Fill from bottom (1) up to calculated height (h)
            # Use max(1, h) to ensure there is at least a base line
            for y in 1:max(1, h)
                solid_setup[x, y] = 1
            end
        end
    end


elseif initial_params.initial_solid_setup_type == :triangle

    #Integer Division
    center_x = initial_params.width ÷ 2
    tri_half_width = 15  
    tri_height = 100      

    # Only loop through the range of the triangle itself
    # This leaves solid_setup as 0 everywhere else
    for x in (center_x - tri_half_width):(center_x + tri_half_width)
        # Ensure we stay within the horizontal bounds of the simulation
        if 1 <= x <= initial_params.width
            dist = abs(x - center_x)
            
            # Linear decay for a sharp point
            h = Int(ceil(tri_height * (1 - (dist / tri_half_width))))
            
            # Fill from y=1 up to h. If h is 0 (at the very edges), nothing is filled.
            for y in 1:h
                solid_setup[x, y] = 1
            end
        end
    end

            
else
    solid_setup[:, 1] .= 1
end

initial_params.solid = solid_setup

# Create ABM
model = ABM(
    Union{Sediment, MicrobeMat}, 
    space; 
    properties = initial_params,
    rng, 
    agent_step! = agent_step!, 
    model_step! = world_step!,
    warn = false,
    scheduler = Schedulers.Randomly()
)

# Add microbes based on initial_microbe_density
for x in 1:model.width
    for y in 1:model.height
        if solid_setup[x, y] != 0 && rand(rng) < initial_params.initial_microbe_density
            add_agent!((x, y), MicrobeMat, model)
        end
    end
end

return model

    end


# --- Usage  and test set-up 
# 1. Create a parameter instance- This can be defaulted or can modify individual parameters
my_params = WorldParameters(sediment_amplitude=20, precip_probs=0.9, width=1000)

# 2. Initialise the model, rng is not required but can be added
model = makeworld(my_params)










function stopping_function(model, t)

    
    # The condition that returns the final boolean
    condition_met = model.max_height > ( model.height - 50) || t >= num_steps
    
    
    return condition_met
end


#Function to colour the agents when plotting them 
function agent_color(agent)
    if agent isa MicrobeMat
        return :green # Color for MicrobeMat agents
    elseif agent isa Sediment
        return :gray # Color for Sediment agents
    else
        return :gray # Default color for any other unexpected types
    end
end
    




GLMakie.activate!(render_on_demand = true)


get_solid_setup(model) = model.solid


plotkwargs = (
    agent_size = 5, 
    heatarray = get_solid_setup,
    heatkwargs = (colorrange = (0, 3), colormap = :gnuplot),
    agent_color = agent_color,
          
    #colorbar = false, 
    add_colorbar = false,
    rasterize = 5
)


model_params = WorldParameters( sediment_amplitude= 50,
    downspeed= 2,
    width = 1500,
    height = 950,
    recolonisation_prob =0.99 ,
    period_control_T= 500,
    precip_amplitude=0.1,
    stability_dist = 20,
    attraction_dist = 20,
    precip_period_scaling=2,
sediment_periodic_mode = :max_cos,
    precip_periodic_mode=  :max_cos,
    precip_weights_down_side_up = [1,1,3],
    conical_scale= 0,
    distance_metric = :euclidean,
    #options should be :euclidean, :manhattan, :chebyshev
    initial_solid_setup_type = :baseline,
    #initial_solid_setup_type =:triangle,
    remove_probs=0.02,
    prevent_overhang = false
        )

    #Set-up model with or without seed 
    
    model = makeworld(model_params,  rng = Xoshiro())

slider_params = [
    
    :attraction_dist => 1:1:50,    
    :stability_dist => 1:1:50,


    :precip_amplitude => 0.0001:0.01:0.99,

    :sediment_amplitude => 1:1:100,

    #:conical_scale => 0:0.1:3,

    :period_control_T => 1:1:1000,

    :precip_period_scaling => 0.2:0.1:5,

    :precip_period_offset => 0:10:1000,
        
    :recolonisation_prob => 0.1:0.01:0.99,

    :remove_probs => 0.01:0.01:1,

]


fig, abmobs = abmexploration(model;
    figure = (size = (1000, 1000),),
    params = slider_params, asleep = 0.0,
    plotkwargs...,
    #add_colorbar = false,
    #hidedecorations = true,
    )
display(fig)




