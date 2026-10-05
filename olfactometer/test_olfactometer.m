% test_olfactometer  Click every odour valve in turn, untriggered, on the rig.
%
%   Plays each odour valve (3-8, 11-16) for one pulse, three rounds, and prints how
%   long each took. Uses olfactometer.Olfactometer (Olfactometer repo) with the
%   rig config; the valves are idled and the session closed however it ends. For
%   a window with a sequence preview, use olfactometer.app('Config', luminose.olfactometer).

luminose = LuminoseConstants();
olf = olfactometer.Olfactometer('Config', luminose.olfactometer);
cleanup = onCleanup(@() olf.disconnect());
olf.connect();
olf.idle();
for round = 1:3
    for valve = olfactometer.Olfactometer.OdourValves
        tic
        olf.play(valve, 1);
        fprintf('valve %2d: %.3f s\n', valve, toc);
    end
end
