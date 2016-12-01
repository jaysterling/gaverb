
# GAVerb

This repository contains the Matlab and C++ source code I developed in working on my Masters Thesis at the University of Miami under Will Pirkle. The work investigates the use of the Genetic Algorithm for guiding the automatic design of FDN reverb parameters to perceptually match some target room impulse response's sound.

More info on the algorithm steps can be found in the [full thesis here](www.jaycoggin.com/home/automatic-fdn-reverb-design-using-the-genetic-algorithm/) or the [condensed AES paper here](http://www.aes.org/e-lib/browse.cfm?elib=18470)

The optimization algorithm is implemented in MATLAB using the global optimization toolbox's genetic algorithm. The number crunching to generate each synthetic FDN IR for comparison is done in a command line app called from MATLAB during each iteration.

### Folder Organization

The root folder contains these directories:

- matlab : All Matlab source is in here
- C++ : Xcode project and sources for command line FDN processing utility called fdnreverb
- Sounds : Input and output audio clips

### Getting Started

1. The GAVerb MATLAB source has a single dependency, MIRToolbox, which is a collection of many audio utilities. It would be nice to get rid of this dependency, but for now, it's necessary. It's free, but you'll need to fill out a download request form from the owner's webpage [here](https://www.jyu.fi/hum/laitokset/musiikki/en/research/coe/materials/mirtoolbox). Add the root folder of the download to your MATLAB path.
2. In MATLAB, `cd gaverb`. This is because some scripts assume the current directory to be the top level of this repo
3. Add the 'matlab' and 'Sounds' directories and sub-directories to your MATLAB path
4. Open RunTopLevel.m located in the matlab/TopLevel/ folder and run the script. You're now optimizing!
5. (Optional) If you're interested in rebuilding the C++ source, run `git submodule init` then `git submodule update` to clone the FFTConvolver submodule. A pre-built fdnreverb binary is packaged with the repo so building this isn't required

### MATLAB Source Organization

There are a lot of files, so where should you begin? Start in RunTopLoevel.m in matlab/TopLevel/ This is where you can hit "Run" and kick the optimization into motion. There are many parameters at the top that affect the way the algorithm runs: which wav file is the target IR, what size the FDN should be, etc. This info goes into a global state structure called 'st' that you'll see referenced in many files.

If you scroll down, there's some plot generation code and then a call to runGA(). In here, we take the parameters from st and setup the actual GA function input options, like how many of each variable to generate, what each's range is, etc. Near the bottom, we call ga() itself with all of our options and a function handle to our fitness function it will call us back at to generate a fitness value with its output parameters. That function is called rirFit. 

If you look at rirFit(), it has a couple switches depending on the optimization method, as well plot generation, but ultimately it calls doFDNReverbWithGAOutput() with the GA parameters. This is where the meat of the synthetic IR generation is. We pick out our parameters from the list the GA returned, call into designFDNFiltToRT60Curve() which designs the IIR filters to match the T60(f) target curve, then call the command line FDN app in fdnReverbFast() to generate the synthetic IR. We return back to rirFit() the final set of FDN parameters with all analytically designed pieces as well (decay filters, tonal correction filter). rirFit() then calls getFitnessValue() with the target and synthetic IRs, and depending on the fitness function defined in the global state variable, the different fitness methods are implemented.

So at a high level, starting the algorithm goes like:

- `RunTopLevel` 		setup options for running
- `runGA`          		translate our options to matlab ga options
- `ga`              		invoke the Matlab GA with our options and our fitness callback

Fitness Callback Flow:

- `rirFit`           		called by GA with current output parameters
- `doFDNReverbWithGAOutput`   	Design analytical pieces and generate synthetic IR
- `getFitnessValue`    	Pass in synthetic and target IR, returns fitness value




