package jaztest;

/**
 * Compile me with Java 16!
 */
public class Test {
    public static boolean lorisBestie(boolean isJoeMama) {
        return !isJoeMama;
    }
    
    public static int test() {
        return lorisBestie(false) ? 420 : 0;
    }

    public static void main(String[] args) {
        System.out.println(test());
    }
}
