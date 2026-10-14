function [fig, ax] = createFigure(varargin)
% lhf.plot.createFigure  One window holding every live plot of a behaviour protocol.
%
%   [fig, ax] = lhf.plot.createFigure()
%   [fig, ax] = lhf.plot.createFigure('Visible', 'off')   (extra figure properties)
%   [fig, ax] = lhf.plot.createFigure('WithPower', true, ...)
%   [fig, ax] = lhf.plot.createFigure('WithDprime', true, ...)
%
%   A single graphics canvas instead of one per plot. The outcome plot spans
%   the top row; accuracy, reward, response time and encoder sit in a 2x2
%   grid below it. ax is a struct of axes: ax.Outcome, ax.Accuracy,
%   ax.Reward, ax.Response, ax.Encoder. With 'WithPower', true a fourth row
%   spans the window for performance against laser power, ax.Power
%   (lhf.plot.power). With 'WithDprime', true a row spanning the window under the
%   2x2 grid holds the moving d' of a go/no-go task, ax.Dprime (lhf.plot.dprime).

    [withPower, varargin] = takeOption(varargin, 'WithPower');
    [withDprime, varargin] = takeOption(varargin, 'WithDprime');

    fig = figure('Position', [30 285 1000 1100], ...
        'name', 'Live Plots', 'numbertitle', 'off', 'MenuBar', 'none', 'Resize', 'on', ...
        varargin{:});
    t = tiledlayout(fig, 3 + withDprime + withPower, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax.Outcome  = nexttile(t, [1 2]);
    ax.Accuracy = nexttile(t);
    ax.Reward   = nexttile(t);
    ax.Response = nexttile(t);
    ax.Encoder  = nexttile(t);
    if withDprime
        ax.Dprime = nexttile(t, [1 2]);
    end
    if withPower
        ax.Power = nexttile(t, [1 2]);
    end
end


function [value, options] = takeOption(options, name)
% A logical name-value option taken out of the figure properties (false if absent).
    value = false;
    k = find(strcmpi(options(1:2:end), name), 1);
    if ~isempty(k)
        value = logical(options{2*k});
        options(2*k-1:2*k) = [];
    end
end
