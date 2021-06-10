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

    public static void main() {
        Benjamin b = new Benjamin();
        IZiguana i = b;

        i.getAwesomeness();
    }
}
