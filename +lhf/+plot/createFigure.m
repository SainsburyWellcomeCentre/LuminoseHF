function [fig, ax] = createFigure(varargin)
% lhf.plot.createFigure  One window holding every live plot of a behaviour protocol.
%
%   [fig, ax] = lhf.plot.createFigure()
%   [fig, ax] = lhf.plot.createFigure('Visible', 'off')   (extra figure properties)
%   [fig, ax] = lhf.plot.createFigure('WithPower', true, ...)
%
%   A single graphics canvas instead of one per plot. The outcome plot spans
%   the top row; accuracy, reward, response time and encoder sit in a 2x2
%   grid below it. ax is a struct of axes: ax.Outcome, ax.Accuracy,
%   ax.Reward, ax.Response, ax.Encoder. With 'WithPower', true a fourth row
%   spans the window for performance against laser power, ax.Power
%   (lhf.plot.power).

    withPower = false;
    k = find(strcmpi(varargin(1:2:end), 'WithPower'), 1);
    if ~isempty(k)
        withPower = logical(varargin{2*k});
        varargin(2*k-1:2*k) = [];
    end

    fig = figure('Position', [30 285 1000 1100], ...
        'name', 'Live Plots', 'numbertitle', 'off', 'MenuBar', 'none', 'Resize', 'on', ...
        varargin{:});
    t = tiledlayout(fig, 3 + withPower, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax.Outcome  = nexttile(t, [1 2]);
    ax.Accuracy = nexttile(t);
    ax.Reward   = nexttile(t);
    ax.Response = nexttile(t);
    ax.Encoder  = nexttile(t);
    if withPower
        ax.Power = nexttile(t, [1 2]);
    end
end
