/* Prism grammars tailored to the sources in this collection. */
if (window.Prism) {
  Prism.languages['c64-basic'] = {
    'string': { pattern: /"[^"\r\n]*(?:"|(?=\r?$))/m, greedy: true },
    'comment': { pattern: /\bREM[^\r\n]*/i, greedy: true },
    'line-number': { pattern: /^\d+/m, alias: 'number' },
    'keyword': /\b(?:CLOSE|CLR|CMD|CONT|DATA|DEF|DIM|END|FN|FOR|GET|GOSUB|GOTO|IF|INPUT|LET|LIST|LOAD|NEW|NEXT|ON|OPEN|POKE|PRINT|READ|RESTORE|RETURN|RUN|SAVE|STEP|STOP|SYS|THEN|TO|VERIFY|WAIT)\b/i,
    'function': /\b(?:ABS|ASC|ATN|CHR\$|COS|EXP|FRE|INT|LEFT\$|LEN|LOG|MID\$|PEEK|POS|RIGHT\$|RND|SGN|SIN|SPC|SQR|STR\$|TAB|TAN|USR|VAL)(?=\s*\()/i,
    'number': /(?:\b\d+(?:\.\d*)?|\B\.\d+)(?:E[+-]?\d+)?/i,
    'operator': /[+\-*/^=<>]|\b(?:AND|NOT|OR)\b/i,
    'punctuation': /[,;:()]/
  };
  Prism.languages['acme-6502'] = Prism.languages.extend('asm6502', {
    'directive': { pattern: /!\w+\b|\.\w+(?=\s)/, alias: 'property' },
    'operator': /[+\-*/=<>#&|^~]/
  });
  Prism.languages.insertBefore('acme-6502', 'op-code', {
    'label': { pattern: /^\s*[a-z_]\w*(?=:)/im, alias: 'function' }
  });
}

function highlightSource(element, program, source) {
  const language = program.language === 'machine-code' ? 'acme-6502' : 'c64-basic';
  element.className = `language-${language}`;
  // Assign text before highlighting, so source cannot inject HTML.
  element.textContent = source;
  if (window.Prism) Prism.highlightElement(element);
}
