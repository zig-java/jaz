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
        int z = 0;

        switch (z) {
            case 0:
                return 20;

            case 1:
                return 69;

            case 2:
                return 420;

            case 3:
                return 15;
        
            default:
                break;
        }

        return 0;
    }
}