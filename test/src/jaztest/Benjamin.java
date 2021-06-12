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
        int z = 2;
        int b = 0;

        switch (z) {
            case 0:
                b = 10;
                break;

            case 1:
                b = 69;
                break;

            case 2:
                b = 420;
                break;

            case 3:
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