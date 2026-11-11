// Sample for scripts/check.lua.
function greet(name, times = 1) {
  return Array.from({ length: times }, () => `hello ${name}`).join(", ");
}

console.log(greet("world", 2));
