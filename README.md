# Agent-based Modelling of Microbialite Formation through Sedimentation and Precipitation Dynamics








<video src="https://github.com/user-attachments/assets/af00000d-ee5a-4205-bd4b-3dce89d1bf6a" 
       autoplay 
       muted 
       loop 
       playsinline 
       style="max-width: 100%;">
</video>





The repository contains the code and data associated with the paper "Agent-based modelling of Microbialite Formation through Sedimentation and Precipitation Dynamics" by Niall Rodgers, Laurane Fogret, Mark Van Zulien, Sudha Rajamani, Henderson Cleaves and Sean McMahon. 


This repository contains the main notebook which was used to generate the data in the paper as well as the interactive simualtor in notebook form and as a .jl file.  

To understand the workings of the model likely the interactive simulator code is probably the cleanest to read as it does not require all the plotting, measurement and parrellisation code. Extensions and your own plotting can likley be made by your friendly LLM of choice given this base. 

Manuscript has been submitted to EarthArxiv under the name given above.

## Interactive Simulator 


The interactive simualtion allows you to interact with the model and change the parameters with without interfacing with the code. This can be down in two ways eitehr running the interactive notebook or running the .jl file from the command line/terminal. 

In order to run either of these Julia must be installed. This is very easy to do and should only take a few minutes and can be done by following the instructions at https://julialang.org/downloads/ 

When this is down the code needs to run and install the required packages [Agents, LinearAlgebra, Random, StatsBase, GLMakie] all .jl. This is cheked for automatically on the first run of the .jl file so the first run will take longer while things installed but then the code should start staight away after this. If you wish to disable this and install yourself this can be removed from the code. 


To run the .jl file simply launch the julia code by typing ""julia -i "path to .jl file" "" into your terminal or command prompt and this will start the code and the interaactive simulations should start in a new window. You can then set sleep to zero to stop pauses between timesteps, press run start the simulation and then reset the parameters as required.

The simualtion should be quite responsive depending on how you setup the number of time steps per frame and your system. Julia should work on most machines so hopefully compatablity shoud not be a problem. 

Running the simulation for the jupyter notebook just requires having julia linked to your jupyter envirnoment and then running all cells in the notebook and the simulation will begin. 


If you wish to modify the values or variables on the interactive sliders then the relevant lines at the end of the code in either the .jl file or in the notebook can be edited to any values you wish which respect the constraints of the model. Due to the way things are setup you can not change intial conditions intractively and these can be edited by changing the value in the parameter fucntion in the code. 


## Measurement, Morphospace and Single Object Notebook

The full notebook which was used to generate the results of the paper is also given. This is broken into dfferent cell section which alow generation of a single object for a set of parameters, generating a morphospace or sampling a large number of parameters as described in the paper.






## Video Generation Notebook

We also included a version of the notebook which simply makes videos of the dynamics, where parameters can be set by modifying the notebook. A few example videos are uploaded in this repo, however files are compressed to make them easier to upload so quality is not the same as the orginal resolution.



## Uploaded Data Files

Uploaded data files are stored in a the folder called Github Upload. The videos are given in one folder while the results of each of the two quantitative sweeps. 

In the quantitative sweeps folder we have several objects. We have a .csv file which gives a unique label for every simulation and all the measured results for this simulation. This unqiue name is used to name a small .jpg file and a .hdf5 file which can be used to either visualise the results or replot them. We also do pairwise plots of all combinations of input variables and measurements for each quantative sweep.  






For questions email niall.rodgers at ed.ac.uk University of Edinburgh 





