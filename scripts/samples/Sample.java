// Sample for scripts/check.lua.
import java.util.List;

public class Sample {
    static String greet(String name, int times) {
        return String.join(", ", java.util.Collections.nCopies(times, "hello " + name));
    }

    public static void main(String[] args) {
        List<String> names = List.of("world");
        System.out.println(greet(names.get(0), 2));
    }
}
