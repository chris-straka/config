# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:$HOME/.docker/bin"
# End of Docker Desktop section.

eval "$(/opt/homebrew/bin/brew shellenv)"
# Add .NET Core SDK tools
export PATH="$PATH:$HOME/.dotnet/tools"

# ccez/hosts/mac.sh (this marker stops mac.sh appending its own copy): the
# agent-host tools on fleet Macs. Each dir is only added where it exists.
for d in "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.bun/bin" /opt/homebrew/opt/node@24/bin; do
  [ -d "$d" ] && export PATH="$d:$PATH"
done
[ -f "$HOME/.config/cz-host/env.sh" ] && . "$HOME/.config/cz-host/env.sh"
