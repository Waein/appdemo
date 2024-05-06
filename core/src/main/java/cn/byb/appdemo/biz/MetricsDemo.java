package cn.byb.appdemo.biz;

import cn.fraudmetrix.metrics.Measurement;
import cn.fraudmetrix.metrics.MeasurementKey;
import cn.fraudmetrix.metrics.MetricTimer;
import cn.fraudmetrix.metrics.Registry;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class MetricsDemo {

    @Autowired
    Registry registry;

    public Measurement getRtMeasurement() {
        MeasurementKey memcacheMeasKey = new MeasurementKey("appdemoRtBiao");
        Measurement measurement = registry.getMeasurement(memcacheMeasKey);
        return measurement;
    }

    public Measurement getTpsMeasurement() {
        MeasurementKey memcacheMeasKey = new MeasurementKey("appdemoTpsBiao");
        Measurement measurement = registry.getMeasurement(memcacheMeasKey);
        return measurement;
    }

    public void executeRt() {
        Measurement measurement = getRtMeasurement();
        MetricTimer.Context timer = measurement.metricTimer("rt");
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        timer.stop();
    }

    /**
     * gauge, 计量用于采样数值的大小，比如下面采集的活动线程数
     */
    public void executeTps() {
        Measurement measurement = getTpsMeasurement();
        measurement.counter2("executeTag").mark();
    }

}
