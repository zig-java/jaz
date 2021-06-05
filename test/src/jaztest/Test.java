package jaztest;

/**
 * Compile me with Java 16!
 */
public class Test {
    public static int funky() {
        return Integer.bitCount(12);
    }

    public static void main(String[] args) {
        System.out.println(funky());
    }
}
