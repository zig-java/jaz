package jaztest;

public class Benjamin implements IZiguana {
    @Override
    public int getAwesomeness() {
        return (int) (getPoggersiness() * 10);
    }

    @Override
    public float getPoggersiness() {
        return 10.5f;
    }

    public static int main() {
        float bruh1 = 1;
        double bruh = (double) bruh1;
        int z = (int) bruh;
        int b = 0;

        switch (z) {
            case 0:
                b = 10;
                break;

            case 1:
                b = 69;
                break;

            case 3000:
                b = 15;
                break;
        
            default:
                break;
        }

        return b;
    }

    public static void main(String[] args) {
        System.out.println(main());
    }
}