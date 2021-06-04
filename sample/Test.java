package sample;

/**
 * Compile me with Java 16!
 */
public class Test {
    public static boolean lorisBestie() {
        return true;
    }
    
    public static int test() {
        if (lorisBestie()) return 420;
        else return 0;
    }

    public static void main(String[] args) {
        System.out.println(test());
    }
}
