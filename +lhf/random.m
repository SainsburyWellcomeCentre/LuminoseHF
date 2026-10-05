function out = random(action, seed)
% lhf.random  The session's random numbers, from one recorded seed.
%
%   seed = lhf.random('init')        seed from the clock
%   seed = lhf.random('init', seed)  seed with a given number (repeat a session)
%   s    = lhf.random()              the session stream (a RandStream)
%   seed = lhf.random('seed')        the seed in use
%
%   Protocols call 'init' once at START and store the seed in
%   Data.RandomSeed. Trial types, the ITI order and odour rows draw from the
%   returned stream. MATLAB's global stream is seeded from it too (seed + 1),
%   for the code that draws with rand/normrnd directly (pattern rows, random
%   spots, the barcode). A repeated seed repeats the stream's draws; draws on
%   the global stream also depend on the order soft codes arrive in.

    persistent stream sessionSeed

    if nargin == 0
        if isempty(stream)
            lhf.random('init');
        end
        out = stream;
        return
    end

    switch action
        case 'init'
            if nargin < 2 || isempty(seed)
                seed = mod(floor(posixtime(datetime('now')) * 1000), 2^31 - 2);
            end
            sessionSeed = double(seed);
            stream = RandStream('mt19937ar', 'Seed', sessionSeed);
            rng(sessionSeed + 1, 'twister');
            out = sessionSeed;
        case 'seed'
            out = sessionSeed;
        otherwise
            error('lhf:random:action', 'Unknown action ''%s''.', action);
    end
end
