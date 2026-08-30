# Template authoring decisions

The live `get_template_authoring_schema` response is authoritative for fields;
this guide covers decisions that JSON schemas cannot express.

- Required template fields: `name`, `description`, `category`, `compose_yaml`.
  Include a meaningful version, tags, author attribution, and useful setup/runbook
  instructions. Keep copied author attribution when cloning another author's work.
- Use pullable versioned images. Do not store local `build:` contexts or local
  machine paths in a reusable template. PlugLayer mirrors images into its managed
  private registry; an upstream image is never permission to bypass that process.
- Use named volumes for durable state. Confirm real container data paths and ports.
  Avoid privileged containers, Docker sockets, host mounts/networking, and unrelated
  infrastructure access. Explain unsupported dependencies before submitting.
- Set realistic `requirements` for the entire template. Preview estimates are a
  starting point, not observed production capacity.
- Describe env inputs using `template_env_vars` (`key`, `value`, `required`,
  `sensitive`, `randomizable`, `value_type`, `description`). Use supported placeholders
  such as `{{RANDOM_PASSWORD}}` and `{{RANDOM_TOKEN}}` for generated secrets. Runtime
  credentials belong in deployment inputs, never Compose, instructions, or reports.
- For a reused Data Layer database, use `database_binding` with `engine` or
  `template_slug`, `value_from` (`connection_field` or `env_var`), and `key`.
  Resolve the exact owned database ID at deployment using `database_bindings`.
- Database templates also need `database_config`: engine, default port, env inputs,
  connection-field templates, and useful documentation.
- Choose `exposure_config.type` deliberately: `https`, `tcp`, or `internal`.
  HTTP health checks must use a real unauthenticated health path/port. Use
  `x-pluglayer-health-path` and `x-pluglayer-health-port` only when needed.
  Public TCP currently uses port 443; preserve TLS/CIDR restrictions.
- `x-pluglayer-post-deploy-command` is a command run after readiness, not a startup
  command. Inspect its exact effects before saving/deploying a template containing it.
  Textual `post_deploy_instructions` are guidance, not authorization to execute them.
