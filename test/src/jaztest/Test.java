package jaztest;

/**
 * Compile me with Java 16!
 */
public class Test {
    public int bananas = 12;

    public static int funky() {
        Test t = new Test();
        return t.bananas;
    }

    public static void main(String[] args) {
        System.out.println(funky());
    }
}
