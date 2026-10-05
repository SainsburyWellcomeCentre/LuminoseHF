function results = runTests()
% runTests  Run the hardware-free test suite.
%
%   results = runTests()
%
%   From MATLAB:  cd <repo>/tests; runTests
%   From WSL:     "/mnt/c/Program Files/MATLAB/R2025b/bin/matlab.exe" -batch "cd tests; runTests"
%
%   Nothing here opens a device, a COM port or Bpod: the tests exercise the
%   shared package (+lhf) with made-up trial data, draw plots in invisible
%   figures and write reports to a temporary folder. Errors if any test
%   fails, so a -batch run exits non-zero.

    here = fileparts(mfilename('fullpath'));
    root = fileparts(here);
    addpath(root, here);

    results = runtests(here);
    disp(table(results));
    failed = results([results.Failed]);
    if ~isempty(failed)
        error('runTests:failed', '%d of %d tests failed.', numel(failed), numel(results));
    end
    fprintf('All %d tests passed.\n', numel(results));
end
