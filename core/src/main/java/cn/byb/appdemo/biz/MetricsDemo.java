package cn.byb.appdemo.biz;

import org.apache.tomcat.util.modeler.ManagedBean;
import org.apache.tomcat.util.modeler.Registry;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class MetricsDemo {

    @Autowired
    Registry registry;

    public ManagedBean getRtMeasurement() {
        return registry.findManagedBean("appdemoRtBiao");
    }

    public ManagedBean getTpsMeasurement() {
        return registry.findManagedBean("appdemoTpsBiao");
    }

    public void executeRt() {
        ManagedBean rtBiao = getRtMeasurement();
        String rtBiaoName = rtBiao.getName();
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    /**
     * gauge, 计量用于采样数值的大小，比如下面采集的活动线程数
     */
    public void executeTps() {
        ManagedBean tpsBiao = getTpsMeasurement();
        String tpsBiaoName = tpsBiao.getName();
    }

}
