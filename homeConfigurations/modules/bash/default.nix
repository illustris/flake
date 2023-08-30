{ ... }:
{
	programs.bash = {
		enable = true;
		historyControl = [ "erasedups" ];
		historyFileSize = -1;
		historySize = -1;
		initExtra = ''
			export PROMPT_COMMAND="history -a;$PROMPT_COMMAND"
			if [ "$TERM" != "dumb" -o -n "$INSIDE_EMACS" ]; then
				PROMPT_COLOR="1;31m"
				let $UID && PROMPT_COLOR="1;36m"
				PS1="\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\\$\[\033[0m\] "
			fi
		'';
		shellAliases = {
			genpass = "cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 2";
			grep = "grep --color";
		};
	};
}
