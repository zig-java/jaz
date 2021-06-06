package jaztest;

/**
 * Compile me with Java 16!
 */
public class Test {
    public static int funky() {
        int[] myFavoriteThings = {1, 3, 5};
        int a = 0;
        for (int b : myFavoriteThings) a += b;
        return a;
    }

    public static void main(String[] args) {
        System.out.println(funky());
    }
}
