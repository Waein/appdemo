package cn.byb.appdemo.util;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;

public class SeqIdUtil {

    private static final SecureRandom RANDOM = new SecureRandom();
    private static char[] digits = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};

    public static String getUniqIDHash() {
        byte[] randomBytes = new byte[16];
        RANDOM.nextBytes(randomBytes);

        MessageDigest digest = null;
        if (digest == null) {
            try {
                digest = MessageDigest.getInstance("MD5");
            } catch (NoSuchAlgorithmException e) {
                throw new IllegalStateException("md5 algorithm not found.", e);
            }
        }

        byte[] bt = digest.digest(randomBytes);
        int l = bt.length;

        char[] out = new char[l << 1];

        for (int i = 0, j = 0; i < l; i++) {
            out[j++] = digits[(0xF0 & bt[i]) >>> 4];
            out[j++] = digits[0x0F & bt[i]];
        }

        return new String(out);
    }

    public static boolean isMacOs() {
        String os = System.getProperty("os.name");
        if (os.startsWith("Mac")) {
            return true;
        }
        return false;
    }

}
