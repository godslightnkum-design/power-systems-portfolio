%% PROJECT 1 - 5-Bus Load Flow Study (MATLAB Newton-Raphson)
%  Run this file. It solves 4 scenarios, prints results, saves a figure
%  and a CSV summary into ../results/.
clear; clc; close all;

baseMVA = 100;

% busdata: [bus type V0   Pg  Pd  Qd  Qsh]     (type 1=slack, 2=PV, 3=PQ)
busdata = [1 1 1.05  0   0   0   0;
           2 2 1.03  80  0   0   0;
           3 3 1.00  0   60  25  0;
           4 3 1.00  0   50  20  0;
           5 3 1.00  0   40  15  0];

% linedata: [from to R X Btotal]  (pu on 100 MVA)
linedata = [1 2 0.02 0.06 0.06;
            1 3 0.08 0.24 0.05;
            2 3 0.06 0.18 0.04;
            2 4 0.06 0.18 0.04;
            3 4 0.01 0.03 0.02;
            4 5 0.08 0.24 0.05];

%% Scenario definitions
names = ["A: Base case"; "B: Peak load (+20%)"; "C: Line 2-4 outage"; "D: Base + 30 Mvar cap at Bus 5"];

busA = busdata;  lineA = linedata;

busB = busdata;  busB(:, 5:6) = 1.2 * busB(:, 5:6);  lineB = linedata;

busC = busdata;  lineC = linedata;  lineC(4, :) = [];      % remove line 2-4

busD = busdata;  busD(5, 7) = 30;   lineD = linedata;

cases = {busA lineA; busB lineB; busC lineC; busD lineD};
ns = numel(names);

%% Solve
results = cell(ns, 1);
Vmat = zeros(5, ns);
for s = 1:ns
    results{s} = loadflow_nr(cases{s, 1}, cases{s, 2}, baseMVA);
    Vmat(:, s) = results{s}.V;
end

%% Print summary
fprintf('\n=== Bus voltages (pu) ===\n');
fprintf('%-32s %7s %7s %7s %7s %7s\n', 'Scenario', 'Bus1', 'Bus2', 'Bus3', 'Bus4', 'Bus5');
for s = 1:ns
    fprintf('%-32s %7.4f %7.4f %7.4f %7.4f %7.4f\n', names(s), Vmat(:, s));
end

fprintf('\n=== System summary ===\n');
fprintf('%-32s %6s %10s %10s %8s\n', 'Scenario', 'Iter', 'Slack MW', 'Loss MW', 'Vmin');
Vmin = zeros(ns,1); VminBus = zeros(ns,1);
for s = 1:ns
    [Vmin(s), VminBus(s)] = min(results{s}.V);
    fprintf('%-32s %6d %10.2f %10.2f %8.4f (bus %d)\n', names(s), ...
        results{s}.iterations, results{s}.slackP, results{s}.lossMW, Vmin(s), VminBus(s));
end

fprintf('\n=== Base case: bus angles (deg) ===\n');
fprintf('Bus %d: %8.4f deg\n', [(1:5); results{1}.thetaDeg']);

fprintf('\n=== Base case: line flows (MW / Mvar) and losses ===\n');
fprintf('%-8s %10s %10s %10s %10s %10s\n', 'Line', 'P_from', 'Q_from', 'P_to', 'Q_to', 'Loss MW');
for k = 1:size(linedata, 1)
    fprintf('%d-%d     %10.2f %10.2f %10.2f %10.2f %10.3f\n', linedata(k,1), linedata(k,2), ...
        real(results{1}.Sf(k)), imag(results{1}.Sf(k)), ...
        real(results{1}.St(k)), imag(results{1}.St(k)), ...
        real(results{1}.Sf(k) + results{1}.St(k)));
end
fprintf('Total losses: %.2f MW\n', results{1}.lossMW);

%% Figure: voltage profile for all scenarios
outdir = fullfile(fileparts(mfilename('fullpath')), '..', 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end

figure('Position', [100 100 900 500]);
bar(1:5, Vmat);
hold on;
yline(0.95, 'r--', '0.95 pu lower limit', 'LineWidth', 1.5);
yline(1.05, 'r--', '1.05 pu upper limit', 'LineWidth', 1.5);
hold off;
ylim([0.7 1.1]);
xlabel('Bus number'); ylabel('Voltage magnitude (pu)');
title('5-Bus System: Voltage Profile by Scenario');
legend(names, 'Location', 'southoutside', 'NumColumns', 2);
grid on;
saveas(gcf, fullfile(outdir, 'matlab_voltage_profile.png'));

%% Save summary CSV
T = table(names, [results{1}.iterations; results{2}.iterations; results{3}.iterations; results{4}.iterations], ...
          cellfun(@(r) r.slackP, results), cellfun(@(r) r.lossMW, results), Vmin, VminBus, ...
          'VariableNames', {'Scenario', 'Iterations', 'SlackMW', 'LossMW', 'Vmin_pu', 'VminBus'});
writetable(T, fullfile(outdir, 'matlab_summary.csv'));
disp(T);
