% --- File: define_race_parameters.m (Enhanced) ---
function race_params = define_race_parameters(race_year, race_name)
    % Defines parameters for the race simulation, potentially specific to a race.
    % INPUTS:
    %   race_year (optional): Year of the race
    %   race_name (optional): Name of the race (e.g., 'Australian Grand Prix')

    fprintf('Defining Race Parameters for %d %s...\n', race_year, race_name);

    % --- Race Setup ---
    % TODO: Potentially load race-specific laps from data or lookup table
    race_params.num_laps = 58; % Example: Default laps (e.g., Bahrain 2023)
    if nargin >= 2 && strcmpi(race_name, 'Australian Grand Prix') && race_year == 2025
        race_params.num_laps = 58; % Adjust if known for specific race
        fprintf('Set laps for %d %s: %d\n', race_year, race_name, race_params.num_laps);
    else
         fprintf('Using default laps: %d\n', race_params.num_laps);
    end


    % --- Tire Rules ---
    race_params.start_compound_idx = 2; % Default: Start on Medium (index 2)
    race_params.must_use_different_compound = true; % F1 rule for >0 stops

    % --- Pit Stop Parameters ---
    % TODO: Pit stop times can vary by track
    race_params.pit_stop_time_loss = 22; % Default seconds lost for a standard pit stop
    race_params.pit_stop_time_loss_sc = 5; % Default seconds lost under SC (usually less than normal)
    fprintf('Using default pit loss: Normal=%.1fs, SC=%.1fs\n', race_params.pit_stop_time_loss, race_params.pit_stop_time_loss_sc);

    % --- Uncertainty Parameters ---
    % TODO: SC probability can vary by track
    race_params.safety_car_probability_per_lap = 0.05; % Default: 5% chance per lap
    race_params.safety_car_duration_laps = 3; % Default: SC lasts 3 laps
    % Consider making SC lap time delta dependent on the *current* tire's base time
    race_params.safety_car_lap_time_delta = 15; % Default: Extra time added to a base lap time under SC
    fprintf('Using default SC probability: %.2f per lap\n', race_params.safety_car_probability_per_lap);

    % --- Simulation Settings ---
    race_params.num_simulations_for_expected_time = 1000; % Number of runs per strategy for uncertainty (increase for accuracy, decrease for speed)
    fprintf('Using %d simulations for expected time calculation.\n', race_params.num_simulations_for_expected_time);

    disp('Race Parameters Defined.');
end