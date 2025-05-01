% --- File: define_race_parameters.m (Track Specific) ---
function race_params = define_race_parameters(race_year, race_name)
    % Defines parameters for the race simulation, specific to a race.

    fprintf('Defining Race Parameters for %d %s...\n', race_year, race_name);

    % --- Defaults ---
    race_params.num_laps = 58; % Default laps
    race_params.start_compound_idx = 2; % Default: Start on Medium (index 2)
    race_params.must_use_different_compound = true;
    race_params.pit_stop_time_loss = 22; % Default pit loss (seconds)
    race_params.pit_stop_time_loss_sc = 5; % Default SC pit loss (seconds)
    race_params.safety_car_probability_per_lap = 0.05; % Default SC probability
    race_params.safety_car_duration_laps = 3; % Default SC duration
    race_params.safety_car_lap_time_delta = 15; % Default SC lap time delta
    race_params.num_simulations_for_expected_time = 1000; % Default number of simulations

    % --- Track Specific Overrides ---
    if contains(race_name, 'Australian', 'IgnoreCase', true)
        race_params.num_laps = 58;
        race_params.pit_stop_time_loss = 21;
        race_params.safety_car_probability_per_lap = 0.06; % Slightly higher than default?
    elseif contains(race_name, 'Monaco', 'IgnoreCase', true)
        race_params.num_laps = 78;
        race_params.pit_stop_time_loss = 20; % Very short pit lane
        race_params.safety_car_probability_per_lap = 0.25; % Much higher SC chance
    elseif contains(race_name, 'Japanese', 'IgnoreCase', true) % Suzuka
        race_params.num_laps = 53;
        race_params.pit_stop_time_loss = 23;
        race_params.safety_car_probability_per_lap = 0.04; % Lower SC chance?
    elseif contains(race_name, 'Bahrain', 'IgnoreCase', true)
        race_params.num_laps = 57;
        race_params.pit_stop_time_loss = 24; % Longer pit lane
        race_params.safety_car_probability_per_lap = 0.03; % Lower SC chance?
    else
        warning('No specific parameters defined for track: %s. Using defaults.', race_name);
    end

    fprintf(' Set Laps: %d\n', race_params.num_laps);
    fprintf(' Set Pit Loss: Normal=%.1fs, SC=%.1fs\n', race_params.pit_stop_time_loss, race_params.pit_stop_time_loss_sc);
    fprintf(' Set SC Probability: %.3f per lap\n', race_params.safety_car_probability_per_lap);
    fprintf(' Using %d simulations for expected time calculation.\n', race_params.num_simulations_for_expected_time);

    disp('Race Parameters Defined.');
end