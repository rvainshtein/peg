# os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
import tensorflow as tf
import dreamerv2.api as dv2
import common
import pathlib
import sys
import ruamel_yaml as yaml

from peg.examples.example_utils import make_env, make_report_render_function, make_eval_fn, make_ep_render_fn, \
  make_cem_vis_fn, make_plot_fn, make_obs2goal_fn, make_sample_env_goals


def main():
  """
  Pass in the config setting(s) you want from the configs.yaml. If there are multiple
  configs, we will override previous configs with later ones, like if you want to add
  debug mode to your environment.

  To override specific config keys, pass them in with --key value.

  python examples/run_goal_cond.py --configs <setting 1> <setting 2> ... --foo bar

  Examples:
    Normal scenario
      python examples/run_goal_cond.py --configs mega_fetchpnp_proprio
    Debug scenario
      python examples/run_goal_cond.py --configs mega_fetchpnp_proprio debug
    Override scenario
      python examples/run_goal_cond.py --configs mega_fetchpnp_proprio --seed 123
  """
  """ ========= SETUP CONFIGURATION  ========"""
  configs = yaml.safe_load((
      pathlib.Path(sys.argv[0]).parent.parent / 'dreamerv2/configs.yaml').read_text())
  parsed, remaining = common.Flags(configs=['defaults']).parse(known_only=True)
  config = common.Config(configs['defaults'])
  for name in parsed.configs:
    config = config.update(configs[name])
  config = old_config =  common.Flags(config).parse(remaining)

  logdir = pathlib.Path(config.logdir).expanduser()
  if logdir.exists():
    print('Loading existing config')
    yaml_config = yaml.safe_load((logdir / 'config.yaml').read_text())
    new_keys = []
    for key in new_keys:
      if key not in yaml_config:
        print(f"{key} does not exist in saved config file, using default value from default config file")
        yaml_config[key] = old_config[key]
    config = common.Config(yaml_config)
    config = common.Flags(config).parse(remaining)
    config.save(logdir / 'config.yaml')
    # config = common.Config(yaml_config)
    # config = common.Flags(config).parse(remaining)
  else:
    print('Creating new config')
    logdir.mkdir(parents=True, exist_ok=True)
    config.save(logdir / 'config.yaml')
  print(config, '\n')
  print('Logdir', logdir)

  """ ========= SETUP ENVIRONMENTS  ========"""
  env = make_env(config, use_goal_idx=False, log_per_goal=True)
  eval_env = make_env(config, use_goal_idx=True, log_per_goal=False, eval=True)
  sample_env_goals = make_sample_env_goals(config, eval_env)
  report_render_fn = make_report_render_function(config)
  eval_fn = make_eval_fn(config)
  plot_fn = make_plot_fn(config)
  ep_render_fn = make_ep_render_fn(config)
  cem_vis_fn = make_cem_vis_fn(config)
  obs2goal_fn = make_obs2goal_fn(config)

  """ ========= SETUP TF2 and GPU ========"""
  set_tf2_and_gpu(config)

  """ ========= BEGIN TRAIN ALGORITHM ========"""
  dv2.train(env, eval_env, eval_fn, report_render_fn, ep_render_fn, plot_fn, cem_vis_fn, obs2goal_fn, sample_env_goals, config)


def set_tf2_and_gpu(config):
  tf.config.run_functions_eagerly(not config.jit)
  # tf.data.experimental.enable_debug_mode(not config.jit)
  message = 'No GPU found. To actually train on CPU remove this assert.'
  assert tf.config.experimental.list_physical_devices('GPU'), message
  for gpu in tf.config.experimental.list_physical_devices('GPU'):
    tf.config.experimental.set_memory_growth(gpu, True)
  assert config.precision in (16, 32), config.precision
  if config.precision == 16:
    from tensorflow.keras.mixed_precision import experimental as prec
    prec.set_policy(prec.Policy('mixed_float16'))


if __name__ == "__main__":
    main()