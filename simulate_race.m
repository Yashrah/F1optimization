% simulate_race.m
function total_time = simulate_race(strategy, race_params, tire_models, use_uncertainty)
    % Simulates a single race for a given strategy and returns the total time.
    % strategy: Nx2 matrix [compound_index, num_laps_on_compound]
    % use_uncertainty: boolean, if true, incorporates random events like SC

    total_time = 0;
    current_lap = 0;
    laps_remaining_in_sc = 0;

    num_stints = size(strategy, 1);

    for stint_idx = 1:num_stints
        compound_idx = strategy(stint_idx, 1);
        stint_laps = strategy(stint_idx, 2);
        tire = tire_models(compound_idx);

        for lap_in_stint = 1:stint_laps
            current_lap = current_lap + 1;
            if current_lap > race_params.num_laps
                break; % Race finished
            end

            tire_age = lap_in_stint;
            base_time = tire.base_lap_time;
            degradation = tire.degradation_func(tire_age);
            lap_time = base_time + degradation;

            % Uncertainty
            if use_uncertainty
                if laps_remaining_in_sc > 0
                    % Currently under Safety Car
                    lap_time = tire_models(1).ref_sc_lap_time + race_params.safety_car_lap_time_delta;
                    laps_remaining_in_sc = laps_remaining_in_sc - 1;
                    % Note: Real SC bunches field, affects pit stop value - complex!
                    % This simple model just makes laps slower.
                else
                    % Check for new Safety Car deployment
                    if rand() < race_params.safety_car_probability_per_lap
                        disp(['Safety Car deployed on lap ', num2str(current_lap)]);
                        laps_remaining_in_sc = race_params.safety_car_duration_laps;
                        % Apply SC effect starting *this* lap
                        lap_time = tire_models(1).ref_sc_lap_time + race_params.safety_car_lap_time_delta;
                        laps_remaining_in_sc = laps_remaining_in_sc - 1;
                    end
                end
            end
          

            total_time = total_time + lap_time;

        end % End laps in stint loop

        % Add pit stop time if not the last stint and race not finished
        if stint_idx < num_stints && current_lap <= race_params.num_laps
            total_time = total_time + race_params.pit_stop_time_loss;
        end

        if current_lap > race_params.num_laps
             break; % Exit stint loop if race finished mid-stint
        end

    end % End stints loop

    % Check if total laps simulated match race laps (can happen if strategy is too short/long)
    if current_lap < race_params.num_laps
        warning('Strategy did not complete the full race distance!');
        total_time = Inf; % Penalize incomplete strategies
    end

end