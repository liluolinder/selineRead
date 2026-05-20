package seline.book.read;

public class seline_read {
    private static int statusBarHeight = 0;
    private static int navigationBarHeight = 0;

    static public String logicTest() {
        return "String returned from logicTest func in java class.";
    }

    static public void setStatusBarHeight(int height) {
        statusBarHeight = height;
    }

    static public void setNavigationBarHeight(int height) {
        navigationBarHeight = height;
    }

    static public int getStatusBarHeight() {
        return statusBarHeight;
    }

    static public int getNavigationBarHeight() {
        return navigationBarHeight;
    }
}