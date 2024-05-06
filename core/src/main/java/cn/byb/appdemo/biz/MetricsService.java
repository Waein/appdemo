package cn.byb.appdemo.biz;

import org.springframework.stereotype.Service;

@Service
public class MetricsService {

    public String getRtMeasurement() {
        return "getRtMeasurement";
    }

    public String getTpsMeasurement() {
        return "getTpsMeasurement";
    }

    public void executeRt() {
        String rtMeasurement = getRtMeasurement();
        System.err.println(rtMeasurement);
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    public void executeTps() {
        String tpsMeasurement = getTpsMeasurement();
        System.err.println(tpsMeasurement);
    }

}
