function fig_dir = setup_figure_dir()
% SETUP_FIGURE_DIR  Return path to figure output directory, creating it if needed.
%
%  fig_dir = setup_figure_dir()
%
%  Resolves to <repo_root>/Lab3_Interpolator/figure/ regardless of the
%  current working directory, since all step scripts live in matlab/.

fig_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'figure');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
end
