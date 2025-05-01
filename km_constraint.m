
function [c, ceq] = km_constraint(vars)
    % Nonlinear constraint function for GA.
    % Ensures K < M (or equivalently K <= M-1, which means K - M + 1 <= 0)
    % vars: Input vector from GA, where vars(1) is K and vars(2) is M.
    % c: Inequality constraints (c(x) <= 0).
    % ceq: Equality constraints (ceq(x) = 0).

    K = vars(1);
    M = vars(2);

    % Constraint is K - M + 1 <= 0
    c = K - M + 1;

    % No equality constraints
    ceq = [];
end
