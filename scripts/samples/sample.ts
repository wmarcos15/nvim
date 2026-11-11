// Sample for scripts/check.lua.
interface User { name: string; age: number }

function greet(user: User, times = 1): string {
  return Array.from({ length: times }, () => `hello ${user.name}`).join(", ");
}

console.log(greet({ name: "world", age: 1 }, 2));
